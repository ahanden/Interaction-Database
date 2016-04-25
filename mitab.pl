#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl mitab.pl [psi-mitab.txt]");
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

    sub getEIDs {
        my($self, $other_id) = @_;
        # Check for valid Entrez IDs
        if($other_id =~ m/entrez\s?gene\/locuslink:(\d+)$/) {
            return $self->getValidEID($1);
        }
        # Check for gene symbols
        elsif($other_id =~ m/entrez\s?gene\/locuslink:(.*)/){
            return $self->symbolToEID($1);
        }
        # Check for UniProt IDs
        elsif($other_id =~ m/uniprotkb:([OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2})/) {
            return $self->crossToEID($1,'UniProt');
        }
        # Check for Ensembl IDs
        elsif($other_id =~ m/ensembl:(\w*?(E|FM|G|GT|P|R|T)\d+)/){
            return $self->crossToEID($1,'Ensembl');
        }
        # Check for miRBase IDs
        elsif($other_id =~ m/mirbase:(MI\d{7})/) {
            return $self->crossToEID($1,'miRBase');
        }
        elsif($other_id =~ m/tair:(AT[0-9]G[0-9]\{5\})/) {
            return $self->crossToEID($1,'TAIR');
        }
        # Any other label gets ignored
        return [];
    }

    sub exec_main {
        my $self = shift;

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";

        $self->log("Checking file size...\n");
        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;
        $self->log("Filling database...\n");
        while (my $line = <$IN>) {
            $self->logProgress();

            # Skip comments
            next if $line =~ m/^#/;

            chomp $line;
            my @fields = split(/\t/,$line);

            # Only include human genes
            next unless $fields[9] =~ m/taxid:9606(\D|$)/ && $fields[10] =~ m/taxid:9606(\D|$)/;

            # Skip genetic interactions
            next if $fields[11] =~ m/psi-mi:"MI:(079\d|0208|0902|0910|0701)"/;

            # Get the Entrez IDs
            my(@eids1, @eids2);
            foreach my $id(split(/\|/,"$fields[0]|$fields[2]|$fields[4]")) {
                push(@eids1,@{getEIDs($self,$id)});
            }
            foreach my $id(split(/\|/,"$fields[1]|$fields[3]|$fields[5]")) {
                push(@eids2,@{getEIDs($self,$id)});
            }

            # Report errors
            if(!@eids1) {
                print "Warning: Unable to find any Entrez IDs to match the first gene at line $..\n";
                next;
            }
            if(!@eids2) {
                print "Warning: Unable to find any Entrez IDs to match the second gene at line $..\n";
                next;
            }

            # Get PubMed IDs
            my @pmids = $fields[8] =~ /pubmed:(\d+)/g;

            # Insert interactions
            foreach my $gene1(@eids1) {
                foreach my $gene2(@eids2) {
                    next if $gene1 == $gene2;
                    if($gene1 > $gene2) {
                        ($gene1, $gene2) = ($gene2, $gene1);
                    }
                    $self->insertInteraction($gene1, $gene2, \@pmids);
                }
            }
        }
        close $IN;
        $self->log("\n");
    }
    print "\n";
}

main();
