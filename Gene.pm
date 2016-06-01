#!/usr/bin/perl

#########################################
# A package for representing a gene and #
# querying the Genes database.          #
#                                       #
# by Adam Handen                        #
#########################################

package Gene;

use strict;
use DBI;
use Term::ReadKey;

my $dbh;
my %queries;

# Caches
my %eid_cache;
my %symbol_cache;
my %cross_cache;

# Initialize the static queries
sub initStaticQueries {
    $queries{eid_check}      = $dbh->prepare("SELECT EXISTS(SELECT * FROM genes WHERE entrez_id = ?)");
    $queries{disc_eid_check} = $dbh->prepare("SELECT entrez_id FROM discontinued_genes WHERE discontinued_id = ?");

    $queries{symbol_check}   = $dbh->prepare("SELECT entrez_id FROM genes WHERE symbol = ?");
    $queries{disc_sym_check} = $dbh->prepare("SELECT entrez_id FROM discontinued_genes WHERE discontinued_symbol = ?");
    $queries{synonym_check}  = $dbh->prepare("SELECT entrez_id FROM gene_synonyms WHERE symbol = ?");

    $queries{cross_check}    = $dbh->prepare("SELECT entrez_id FROM gene_xrefs WHERE Xref_id = ? AND Xref_db = ?");
}

# Updater initialization
sub new {
    my $class = shift;
    my %options = @_;

    my $self = {
        organism => undef,
        entrez_ids => undef,
        primary_id => undef,
        primary_db => undef,
        secondary_ids => [],
        %options,
    };

    bless $self, $class;

    return $self;
}

sub setOrganism {
    my($self, $organism) = @_;

    $self->{organism} = $organism;
}

sub setPrimaryID {
    my ($self, $id, $db) = @_;

    $self->{primary_id} = $id;
    $self->{primary_db} = $db;
}

sub addSecondaryID {
    my ($self, $id, $db) = @_;
    
    push(@{$self->{secondary_ids}}, {id => $id, db => $db});
}

# Returns the Gene's Entrez ID(s)
sub getEIDs {
    my $self = shift;

    # Look up Entrez IDs if necessary
    if(!$self->{entrez_ids}) {
        my @eids;

        # Create the queue of IDs to map to Entrez
        my @to_check;
        if($self->{primary_id}) {
            push(@to_check, {'id' => $self->{primary_id}, 'db' => $self->{primary_db}});
        }
        foreach my $ref(@{$self->{secondary_ids}}) {
            push(@to_check, $ref);
        }

        while(!@eids && @to_check) {
            my $ref = shift(@to_check);

            my $id = $ref->{id};
            my $db = $ref->{db};

            if($db eq "Entrez") {
                @eids = getValidEIDs($id);
            }
            elsif($db eq "Symbol") {
                @eids = symbolToEIDs($id);
            }
            else {
                @eids = crossToEIDs($id, $db);
            }
        }
        $self->{entrez_ids} = \@eids;
    }

    return @{$self->{entrez_ids}};
}

# Connect to a database
sub connectDB {
    my $cnf_file = shift;
    my $debug = shift;

    if($cnf_file) {
        use Cwd 'abs_path';
        my $path = abs_path($cnf_file);
        my $dsn = "DBI:mysql:;mysql_read_default_file=$path";
        $dbh = DBI->connect($dsn, undef, undef, {RaiseError => 1, ReadOnly => 1}) or die;
    }
    else {
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

        $dbh = DBI->connect("dbi:mysql:$db:localhost",$user,$password,{RaiseError => 1, AutoCommit => 0}) or die;
    }

    if($debug) {
        $dbh->trace(2);
    }

    Gene::initStaticQueries();
}

# Check an Entrez ID
sub getValidEIDs {
    my($eid) = @_;

    # Perform queries if the Entrez ID is not in our cache
    if (!exists($eid_cache{$eid})) {
        # Check whether the given Entrez ID is valid
        $queries{eid_check}->execute($eid);
        if($queries{eid_check}->fetch()->[0]) {
            $eid_cache{$eid} = [$eid];
        }
        else {
            # Check if the given Entrez ID corresponds to a discontinued ID
            my @eids;
            $queries{disc_eid_check}->execute($eid);
            while(my $ref = $queries{disc_eid_check}->fetch()) {
                push(@eids,$ref->[0]);
            }
            $eid_cache{$eid} = \@eids;
        }
    }
    return @{$eid_cache{$eid}};
}

# Get an EID from a symbol
sub symbolToEIDs {
    my($symbol) = @_;

    # Perform queries if the symbol is not in our cache
    if(!exists($symbol_cache{$symbol})) {
        my @eids = ();
        # Check if the symbol is a standard, valid symbol
        $queries{symbol_check}->execute($symbol);
        while(my $ref = $queries{symbol_check}->fetch()) {
            push(@eids,$ref->[0]);
        }
        # Check if the given symbol has been discontinued
        if(!@eids) {
            $queries{disc_sym_check}->execute($symbol);
            while(my $ref = $queries{disc_sym_check}->fetch()) {
                push(@eids,$ref->[0]);
            }
        }
        # See if the given symbol is a synonym
        if(!@eids) {
            $queries{synonym_check}->execute($symbol);
            while(my $ref = $queries{synonym_check}->fetch()) {
                push(@eids,$ref->[0]);
            }
        }
        $symbol_cache{$symbol} = \@eids;
    }
    return @{$symbol_cache{$symbol}};
}

# Gets an Entrez ID from an alternative identifier
sub crossToEIDs {
    my($id, $db) = @_;

    # Initialize the cache if it isn't already
    if(!exists($cross_cache{$db})) {
        $cross_cache{$db} = {};
    }

    if(!exists($cross_cache{$db}->{$id})) {
        my @eids;
        $queries{cross_check}->execute($id,$db);
        while(my $ref = $queries{cross_check}->fetch()) {
            push(@eids,$ref->[0]);
        }
        $cross_cache{$db}->{$id} = \@eids;
    }
    return @{$cross_cache{$db}->{$id}};
}

1;
