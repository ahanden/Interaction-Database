#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl hprd.pl [BINARY_PROTEIN_PROTEIN_INTERACTIONS.txt]");
    $updater->update();
}


{
    package myUpdate;
    use base ("Update");
    use Getopt::Long;

    sub checkArgs {
        my $self = shift;

        my $verbose = 0;
        if(GetOptions('verbose' => \$verbose)  && @ARGV == 1) {
            $self->{fname} = $ARGV[0];
            $self->{verbose} = $verbose;
            return 1;
        }
        return 0;
    }
   
    sub getEID {
        my($self, $symbol) = @_;

        if (exists($self->{eid_cache}{$symbol})) {
            return $self->{eid_cache}{$symbol};
        }

        my $eid;

        $self->{eid_query}->execute($symbol);
        my $ref = $self->{eid_query}->fetch();
        if(!$ref) {
            $self->{synonym_query}->execute($symbol);
            $ref = $self->{synonym_query}->fetch();
            if(!$ref) {
                print "Warning: Unable to find an Entrez ID for $symbol\n";
            }
            else {
                $eid = $ref->[0];
            }
        }
        else {
            $eid = $ref->[0];
        }

        $self->{eid_cache}{$symbol} = $eid;

        return $eid;
    }

    sub exec_main {
        my $self = shift;

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";

        $self->log("Filling database...\n");

        $self->{eid_query}     = $self->{dbh}->prepare("SELECT entrez_id FROM genes.genes WHERE symbol = ? AND tax_id = 9606");
        $self->{synonym_query} = $self->{dbh}->prepare("SELECT s.entrez_id FROM (SELECT entrez_id FROM genes.genes WHERE tax_id = 9606) AS g JOIN (SELECT entrez_id FROM genes.gene_synonyms WHERE symbol = ?) AS s ON g.entrez_id = s.entrez_id");
        my $insert_query       = $self->{dbh}->prepare("INSERT IGNORE INTO interactions(entrez_id1, entrez_id2) VALUES (?, ?)");


        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;

        $self->{eid_cache} = {};
        while (my $line = <$IN>) {
            $self->logProgress();

            chomp $line;
            my @terms = split(/\t/,$line);

            my $sym1 = $terms[0];
            my $sym2 = $terms[3];

            next if $sym1 eq "-" || $sym2 eq "-";

            my $eid1 = getEID($self,$sym1);
            my $eid2 = getEID($self,$sym2);

            next if !$eid1 || !$eid2;
            next if $eid1 == $eid2;

            if($eid1>$eid2){
                ($eid1, $eid2) = ($eid2, $eid1);
            }
            $insert_query->execute($eid1, $eid2);

        }
        close $IN;
        $self->log("\n");
    }
}

main();
