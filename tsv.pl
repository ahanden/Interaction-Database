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
   
    sub getEID {
        my($self, $eid) = @_;

        if(exists($self->{eid_cache}->{$eid})) {
            return $self->{eid_cache}->{$eid};
        }

        $self->{eid_check}->execute($eid);
        my $ref = $self->{eid_check}->fetch();
        if($ref->[0]) {
            $self->{eid_cache}->{$eid} = [$eid];
            return [$eid];
        }
        else {
            my @eids;
            $self->{disc_query}->execute($eid);
            while(my $ref = $self->{disc_query}->fetch()) {
                push(@eids,$ref->[0]);
            }
            $self->{eid_cache}->{$eid} = \@eids;
            return \@eids;
        }
    }

    sub exec_main {
        my $self = shift;

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";

        $self->log("Filling database...\n");

        $self->{eid_check}  = $self->{dbh}->prepare("SELECT EXISTS(SELECT * FROM genes.genes WHERE entrez_id = ?)");
        $self->{disc_query} = $self->{dbh}->prepare("SELECT entrez_id FROM genes.discontinued_genes WHERE discontinued_id = ?");
        my $insert_query    = $self->{dbh}->prepare("INSERT IGNORE INTO interactions(entrez_id1, entrez_id2) VALUES (?, ?)");

        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;

        $self->{eid_cache} = {};
        while (my $line = <$IN>) {
            $self->logProgress();

            chomp $line;
            my($gene1, $gene2) = split(/\t/,$line);

            my @eid1 = getEID($self,$gene1);
            my @eid2 = getEID($self,$gene2);

            next if !@eid1 || !@eid2;

            foreach my $g1(@eid1) {
                foreach my $g2(@eid2) {
                    next if $g1 == $g2;
                    if($g1>$g2) {
                        ($g1, $g2) = ($g2, $g1);
                    }
                    $insert_query->execute($g1, $g2);
                }
            }
        }
        close $IN;
        $self->log("\n");
    }
}

main();
