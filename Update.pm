#!/usr/bin/perl

###################################################
# A package for updating the interaction database #
#                                                 #
# by Adam Handen                                  #
###################################################

package Update;

use strict;
use DBI;
use Term::ReadKey;

# Updater initialization
sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
        'verbose' => 0,
        'debug' => 0,
        'dbh' => undef,
        'usage' => "USAGE MESSAGE HERE",
        'progress' => 0,
        'prog_total' => 0,
        %options,
    };

    bless $self, $class;

    if(!$self->checkArgs()) {
        $self->usage();
        exit 1;
    }

    if(!$self->{dbh}) {
        $self->{dbh} = Update::connectDB();
    }

    $self->{insert_query}   = $self->{dbh}->prepare("INSERT INTO interactions (entrez_id1, entrez_id2) VALUES (?, ?) ON DUPLICATE KEY UPDATE int_id=LAST_INSERT_ID(int_id)");
    $self->{insert_pmid}    = $self->{dbh}->prepare("INSERT IGNORE INTO publications (int_id, pubmed_id) VALUES (?, ?)");

    $self->{eid_check}      = $self->{dbh}->prepare("SELECT EXISTS(SELECT * FROM genes.genes WHERE entrez_id = ?)");
    $self->{disc_eid_check} = $self->{dbh}->prepare("SELECT entrez_id FROM genes.discontinued_genes WHERE discontinued_id = ?");

    $self->{symbol_check}   = $self->{dbh}->prepare("SELECT entrez_id FROM genes.genes WHERE symbol = ?");
    $self->{disc_sym_check} = $self->{dbh}->prepare("SELECT entrez_id FROM genes.discontinued_genes WHERE discontinued_symbol = ?");
    $self->{synonym_check}  = $self->{dbh}->prepare("SELECT entrez_id FROM genes.gene_synonyms WHERE symbol = ?");

    $self->{cross_check}    = $self->{dbh}->prepare("SELECT entrez_id FROM genes.gene_xrefs WHERE Xref_id = ? AND Xref_db = ?");
    
    $self->{eid_cache}    = {};
    $self->{symbol_cache} = {};
    $self->{cross_cache}  = {};

    return $self;
}

# Checks commandline arguments
# Should be overridden by implementing class
sub checkArgs {
    # SOME CODE TO OVERIDE HERE
    return 1;
}

# Conditionally write a message to STDERR
sub log {
    my ($self,$message) = @_;
    if($self->{verbose}) {
        print STDERR $message;
    }
}

# Execute an update of the database.
# If it fails, will roll-back the update
sub update {
    my $self = shift;
    eval {
        $self->exec_main();
    };
    if ($@) {
        print STDERR $@;
        print STDERR "Error encountered: rolling back changes.\n";
        $self->{dbh}->rollback();
        exit 1;
    }
    else {
        $self->{dbh}->commit();
    }
}

# The main method. Must be overridden
sub exec_main {
    print STDERR "USING DEFAULT MAIN!\n";
}

# Display the usage statement for the script
sub usage {
    my $self = shift;
    print $self->{usage}."\n";
}

# Connect to a database
sub connectDB {
    my $self = shift;

    ReadMode 1;
    print "dbname: ";
    my $db = <STDIN>;
    chomp $db;
    ReadMode 1;
    print "username: ";
    my $user = <STDIN>;
    chomp $user;
    ReadMode 2;
    print "password: ";
    my $password = <STDIN>;
    print "\n";
    chomp $password;
    ReadMode 1;

    my $dbh = DBI->connect("dbi:mysql:$db:localhost",$user,$password,
        {RaiseError => 1, AutoCommit => 0}) or die;

    if($self->{debug}) {
        $dbh->trace(2);
    }

    return $dbh;
}

# For progress bars
sub logProgress {
    my $self = shift;
    $self->{progress}++;
    if($self->{progess} == 1 || int(100*$self->{progress}/$self->{prog_total}) > int(100*($self->{progress}-1)/$self->{prog_total})) {
        $self->log("Progress: ".int(100*$self->{progress}/$self->{prog_total})."%\r");
    }
}

# Inserts an interaction into the database
sub insertInteraction {
    my $self = shift;
    my $eid1 = shift;
    my $eid2 = shift;

    my @pmids;
    my $ref = shift;
    if($ref) {
        @pmids = @$ref;
    }

    if($eid1>$eid2){
        ($eid1, $eid2) = ($eid2, $eid1);
    }
    $self->{insert_query}->execute($eid1, $eid2);

    my $iid = $self->{insert_query}->{mysql_insertid};
    foreach my $pmid(@pmids) {
        $self->{insert_pmid}->execute($iid,$pmid);
    }

}

# Check an Entrez ID
sub getValidEID {
    my($self, $eid) = @_;

    # Perform queries if the Entrez ID is not in our cache
    if (!exists($self->{eid_cache}->{$eid})) {
        # Check whether the given Entrez ID is valid
        $self->{eid_check}->execute($eid);
        if($self->{eid_check}->fetch()->[0]) {
            $self->{eid_cache}->{$eid} = [$eid];
        }
        else {
            # Check if the given Entrez ID corresponds to a discontinued ID
            my @eids;
            $self->{disc_eid_check}->execute($eid);
            while(my $ref = $self->{disc_eid_check}->fetch()) {
                push(@eids,$ref->[0]);
            }
            if(!@eids) {
                print "Warning: Unable to find a human gene relating to Entrez ID $eid\n";
            }
            $self->{eid_cache}->{$eid} = \@eids;
        }
    }
    return $self->{eid_cache}->{$eid};
}

# Get an EID from a symbol
sub symbolToEID {
    my($self, $symbol) = @_;

    # Perform queries if the symbol is not in our cache
    if(!exists($self->{symbol_cache}->{$symbol})) {
        my @eids;
        # Check if the symbol is a standard, valid symbol
        $self->{symbol_check}->execute($symbol);
        while(my $ref = $self->{symbol_check}->fetch()) {
            push(@eids,$ref->[0]);
        }
        # Check if the given symbol has been discontinued
        if(!@eids) {
            $self->{disc_sym_check}->execute($symbol);
            while(my $ref = $self->{disc_sym_check}->fetch()) {
                push(@eids,$ref->[0]);
            }
        }
        # See if the given symbol is a synonym
        if(!@eids) {
            $self->{synonym_check}->execute($symbol);
            while(my $ref = $self->{synonym_check}->fetch()) {
                push(@eids,$ref->[0]);
            }
        }
        # If nothing comes up, report it
        if(!@eids) {
            print "Warning: Unable to find a valid Entrez ID for input symbol $symbol\n";
        }
        $self->{symbol_cache}->{$symbol} = \@eids;
    }
    return $self->{symbol_cache}->{$symbol};
}

# Gets an Entrez ID from an alternative identifier
sub crossToEID {
    my($self, $id, $db) = @_;

    # Initialize the cache if it isn't already
    if(!exists($self->{cross_cache}->{$db})) {
        $self->{cross_cache}->{$db} = {};
    }

    if(!exists($self->{cross_cache}->{$db}->{$id})) {
        my @eids;
        $self->{cross_check}->execute($id,$db);
        while(my $ref = $self->{cross_check}->fetch()) {
            push(@eids,$ref->[0]);
        }
        if(!@eids) {
            print "Warning: Unable to find a valid Entrez ID for id $id in database $db\n";
        }
        $self->{cross_cache}->{$db}->{$id} = \@eids;
    }
    return $self->{cross_cache}->{$db}->{$id};
}

1;
