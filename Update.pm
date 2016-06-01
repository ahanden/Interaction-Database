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
use Gene;

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
        $self->connectDB();
    }

    $self->{insert_query}   = $self->{dbh}->prepare("INSERT INTO interactions (entrez_id1, entrez_id2) VALUES (?, ?) ON DUPLICATE KEY UPDATE int_id=LAST_INSERT_ID(int_id)");
    $self->{insert_details} = $self->{dbh}->prepare("INSERT IGNORE INTO sources (int_id, pubmed_id, detection_method, int_type) VALUES (?, ?, ?, ?)");

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

    if($self->{cnf_file}) {
        use Cwd 'abs_path';
        my $path = abs_path($self->{cnf_file});
        my $dsn = "DBI:mysql:;mysql_read_default_file=$path";
        $self->{dbh} = DBI->connect($dsn, undef, undef, {RaiseError => 1, AutoCommit => 0}) or die;
    }
    else {
        ReadMode 1;
        print "interaction dbname: ";
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

        $self->{dbh} = DBI->connect("dbi:mysql:$db:localhost",$user,$password,
            {RaiseError => 1, AutoCommit => 0}) or die;
    }

    if($self->{debug}) {
        $self->{dbh}->trace(2);
    }

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
    my $gene1 = shift;
    my $gene2 = shift;
    my $detection_method = shift;
    my $interaction_type = shift;

    my @pmids;
    my $ref = shift;
    if($ref) {
        @pmids = @$ref;
    }

    my $count = 0;

    foreach my $eid1($gene1->getEIDs()) {
        foreach my $eid2($gene2->getEIDs()) {
            # Skip self interactions
            next if $eid1 == $eid2;
            # Sort interacting pairs
            if($eid1>$eid2){ ($eid1, $eid2) = ($eid2, $eid1); }
            # Insert it
            $count++;
            $self->{insert_query}->execute($eid1, $eid2);
            my $iid = $self->{insert_query}->{mysql_insertid};
            foreach my $pmid(@pmids) {
                $self->{insert_details}->execute($iid, $pmid, $detection_method, $interaction_type);
            }
        }
    }

    # Returns the number of inserted interactions
    return $count;
}

1;
