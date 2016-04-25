#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl sin.pl [flat_file.sin]");
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
            my @terms = split(/\t/,$line);

            next if $terms[2] == $terms[3];

            my @eids1 = @{$self->getValidEID($terms[2])};
            next unless @eids1;
            my @eids2 = @{$self->getValidEID($terms[3])};
            next unless @eids2;
            my @pmids = $terms[13] =~ /(\d+)/g;

            foreach my $eid1(@eids1) {
                foreach my $eid2(@eids2) {
                    next if $eid1 == $eid2;
                    $self->insertInteraction($eid1, $eid2, \@pmids);
                }
            }
        }
        close $IN;
        $self->log("\n");
    }
}

main();
