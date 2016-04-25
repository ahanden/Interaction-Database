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
   
    sub exec_main {
        my $self = shift;

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";

        $self->log("Filling database...\n");

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
                push(@genes,@{$self->getValidEID($gene)});
            }
            my @pmids = $terms[7] =~ /(\d+)/g;
            for(my $i = 0; $i < @genes; $i++) {
                my $eid1 = $genes[$i];
                for(my $j = $i + 1; $j < @genes; $j++) {
                    my $eid2 = $genes[$j];

                    next if $eid1 == $eid2;

                    if($eid1 > $eid2) {
                        ($eid1, $eid2) = ($eid2, $eid1);
                    }

                    $self->insertInteraction($eid1, $eid2, \@pmids);
                }
            }
        }
        close $IN;
        $self->log("\n");
    }
}

main();
