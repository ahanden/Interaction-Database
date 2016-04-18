#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl corum.pl [allComplexes.csv]");
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
        my($self, $eid) = @_;

        if (exists($self->{eid_cache}{$eid})) {
            return $self->{eid_cache}{$eid};
        }

        $self->{eid_check}->execute($eid);
        my $ref = $self->{eid_check}->fetch();
        if($ref->[0]) {
            $self->{eid_cache}{$eid} = $eid;
            return $eid;
        }
        else {
            $self->{eid_query}->execute($eid);
            $ref = $self->{eid_query}->fetch();
            if(!$ref) {
                print "Warning: Unable to find a human gene relating to Entrez ID $eid\n";
                return undef;
            }
            else {
                $self->{eid_cache}{$eid} = $ref->[0];
                return $self->{eid_cache}{$eid};
            }
        }
    }

    sub exec_main {
        my $self = shift;

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";

        $self->log("Filling database...\n");

        $self->{eid_cache} = {};
        $self->{eid_check} = $self->{dbh}->prepare("SELECT EXISTS(SELECT * FROM genes.genes WHERE entrez_id = ? AND tax_id = 9606)");
        $self->{eid_query} = $self->{dbh}->prepare("SELECT d.entrez_id FROM (SELECT entrez_id FROM genes.discontinued_genes WHERE discontinued_id = ?) AS d JOIN (SELECT entrez_id FROM genes.genes WHERE tax_id = 9606) AS g ON d.entrez_id = g.entrez_id");
        my $insert_query       = $self->{dbh}->prepare("INSERT IGNORE INTO interactions(entrez_id1, entrez_id2) VALUES (?, ?)");


        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;

        my $header = <$IN>; # Skip the header
        while (my $line = <$IN>) {
            $self->logProgress();
            chomp $line;
            my @terms = split(";",$line);

            # Filter for human genes
            next unless $terms[3] eq "Human";

            # Note: CORUM will list ambiguous subunits of complexes with parenthasis.
            #       We're including every ambiguous protein in the CI regardless.
            $terms[5] =~ s/[\(|\)]//g;
            my @genes;
            foreach my $gene(split(",",$terms[5])) {
                my $eid = getEID($self,$gene);
                if($eid) { push(@genes,$eid); }
            }
            for(my $i = 0; $i < @genes; $i++) {
                for(my $j = $i + 1; $j < @genes; $j++) {
                    my $eid1 = $genes[$i];
                    my $eid2 = $genes[$j];
                    if($eid1 == $eid2) {
                        next;
                    }
                    if($eid1 > $eid2) {
                        ($eid1, $eid2) = ($eid2, $eid1);
                    }
                    $insert_query->execute($eid1, $eid2);
                }
            }
        }
        close $IN;
        $self->log("\n");
    }
}

main();
