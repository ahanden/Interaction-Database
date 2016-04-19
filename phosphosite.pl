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
   
    sub getEID {
        my($self, $symbol) = @_;

        if (exists($self->{symbol_cache}->{$symbol})) {
            return $self->{symbol_cache}->{$symbol};
        }

        my @eids;

        $self->{eid_query}->execute($symbol);
        while(my $ref = $self->{eid_query}->fetch()) {
            push(@eids,$ref->[0]);
        }
        if(!@eids) {
            $self->{synonym_query}->execute($symbol);
            while(my $ref = $self->{synonym_query}->fetch()) {
                push(@eids,$ref->[0]);
            }
            if(!@eids) {
                $self->{disc_symbol_query}->execute($symbol);
                while(my $ref = $self->{disc_symbol_query}->fetch()) {
                    push(@eids,$ref->[0]);
                }
                if(!@eids) {
                    print "Warning: unable to find an Entrez ID for gene symbol $symbol\n";
                }
            }
        }

        $self->{symbol_cache}->{$symbol} = \@eids;

        return \@eids;
    }

    sub exec_main {
        my $self = shift;

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";

        $self->log("Filling database...\n");

        $self->{eid_check}  = $self->{dbh}->prepare("SELECT EXISTS(SELECT * FROM genes.genes WHERE entrez_id = ?)");
        $self->{disc_eid_query} = $self->{dbh}->prepare("SELECT entrez_id FROM genes.discontinued_genes WHERE discontinued_id = ?");

        $self->{eid_query}         = $self->{dbh}->prepare("SELECT entrez_id FROM genes.genes WHERE symbol = ?");
        $self->{synonym_query}     = $self->{dbh}->prepare("SELECT entrez_id FROM genes.gene_synonyms WHERE symbol = ?");
        $self->{disc_symbol_query} = $self->{dbh}->prepare("SELECT entrez_id FROM genes.discontinued_genes WHERE discontinued_symbol = ?");

        my $insert_query = $self->{dbh}->prepare("INSERT IGNORE INTO interactions(entrez_id1, entrez_id2) VALUES (?, ?)");

        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;

        $self->{eid_cache} = {};
        $self->{symbol_cache} = {};
        while (my $line = <$IN>) {
            $self->logProgress();

            chomp $line;
            my @terms = split(/\t/,$line);

            my $symbol1 = $terms[2];
            my $tax1 = $terms[3];
            my $eid2 = $terms[5];
            my $tax2 = $terms[8];
           
            next unless $tax1 && $tax2;
            next unless $tax1 eq "human" && $tax2 eq "human";

            next unless $eid2;

            # Confirm the second Entrez ID
            if(!exists($self->{eid_cache}->{$eid2})) {
                $self->{eid_check}->execute($eid2);
                my $ref = $self->{eid_check}->fetch();
                if($ref->[0]) {
                        $self->{eid_cache}->{$eid2} = $eid2;
                }
                else {
                    $self->{disc_eid_query}->execute($eid2);
                    $ref = $self->{disc_eid_query}->fetch();
                    if($ref) {
                        $self->{eid_cache}->{$eid2} = $ref->[0];
                    }
                    else {
                        print "Warning: unable to find a gene for Entrez ID $eid2\n";
                        next;
                    }
                }
            }
            $eid2 = $self->{eid_cache}->{$eid2};

            my @eids1 = getEID($self,$symbol1);

            next unless @eids1;

            foreach my $eid1(@eids1) {
                next if $eid1 == $eid2;
                if($eid1>$eid2){
                    $insert_query->execute($eid2, $eid1);
                }
                else {
                    $insert_query->execute($eid1, $eid2);
                }
            }

        }
        close $IN;
        $self->log("\n");
    }
}

main();
