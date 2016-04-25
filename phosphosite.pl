#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl phosphosite.pl [Kinase_Substrate_Dataset]");
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

        while (my $line = <$IN>) {
            $self->logProgress();

            chomp $line;
            my @terms = split(/\t/,$line);

            my $symbol1 = $terms[2];
            my $tax1 = $terms[3];
            my $eid2 = $terms[5];
            my $tax2 = $terms[8];
           
            next unless $tax1 && $tax2 && $tax1 eq "human" && $tax2 eq "human";
            next unless $eid2;

            # Confirm the second Entrez ID
            my @eids1 = @{$self->symbolToEID($symbol1)};
            next unless @eids1;

            my @eids2 = @{$self->getValidEID($eid2)};
            next unless @eids2;

            foreach my $eid1(@eids1) {
                foreach $eid2 (@eids2) {
                    next if $eid1 == $eid2;
                    $self->insertInteraction($eid1, $eid2);
                }
            }

        }
        close $IN;
        $self->log("\n");
    }
}

main();
