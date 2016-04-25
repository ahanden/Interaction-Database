#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl tsv.pl [tsv_file]");
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

        $self->{eid_cache} = {};
        while (my $line = <$IN>) {
            $self->logProgress();

            next if $line =~ m/^#/;
            chomp $line;
            my($gene1, $gene2, $pmid) = split(/\t/,$line);

            my @eids1 = @{$self->getValidEID($gene1)};
            my @eids2 = @{$self->getValidEID($gene2)};

            next if !@eids1 || !@eids2;

            foreach my $eid1(@eids1) {
                foreach my $eid2(@eids2) {
                    next if $eid1 == $eid2;
                    $self->insertInteraction($eid1, $eid2, [$pmid]);
                }
            }
        }
        close $IN;
        $self->log("\n");
    }
}

main();
