#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
use Gene;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl mitab.pl --interactions_cnf=[auth.cnf] --genes_cnf=[auth.cnf] [psi-mitab.txt]");
    $updater->update();
}


{
    package myUpdate;
    use base ("Update");
    use Getopt::Long;

    my %db_map = (
        "uniprotkb"            => "UniProt",
        "entrezgene/locuslink" => "Entrez",
        "ensembl"              => "Ensembl",
        "mirbase"              => "miRBase",
        "tair"                 => "TAIR",
        "genbank identifier"   => "GenBank",
        "refseq"               => "RefSeq"
    );

    sub checkArgs {
        my $self = shift;

        my ($verbose, $int_cnf, $gen_cnf, $species);
        if(GetOptions('verbose' => \$verbose,
                    'interactions_cnf=s' => \$int_cnf,
                    'species=s' => \$species,
                    'genes_cnf=s' => \$gen_cnf)  && @ARGV == 1) {
            $self->{fname}    = $ARGV[0];
            $self->{cnf_file} = $int_cnf or die "You must provide a cnf file for access to the interactions database\n";
            $self->{gen_cnf}  = $gen_cnf or die "You must provide a cnf file for access to the genes database\n";
            $self->{verbose}  = $verbose;
            $self->{species}  = $species ? $species : "9606";

            return 1;
        }
        return 0;
    }

    sub exec_main {
        my $self = shift;

        Gene::connectDB($self->{gen_cnf});

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
            next unless $fields[9] =~ m/(\D|^)$self->{species}(\D|$)/ && $fields[10] =~ m/(\D|^)$self->{species}(\D|$)/;

            # Get the Entrez IDs
            my $gene1 = Gene->new();
            my $gene2 = Gene->new();

            my $string = $fields[0]."|".$fields[2]."|".$fields[4];
            while($string =~ /(.*?):(.*?)(\(.*?\))?(\||$)/g) { 
                if($3 && $3 eq "(display_short)") {
                    $gene1->addSecondaryID($2, "Symbol:");
                }
                elsif($1 eq "entrez gene/locuslink") {
                    if($2 =~ m/^\d+$/) {
                        $gene1->addSecondaryID($2, "Entrez");
                    }
                    else {
                        $gene1->addSecondaryID($2, "Symbol");
                    }
                }
                elsif(exists($db_map{lc($1)})) {
                    $gene1->addSecondaryID($2, $db_map{lc($1)});
                }
            }

            $string = $fields[1]."|".$fields[3]."|".$fields[5];
            while($string =~ /(.*?):(.*?)(\(.*?\))?(\||$)/g) { 
                if($3 && $3 eq "(display_short)") {
                    $gene2->addSecondaryID($2, "Symbol");
                }
                elsif($1 eq "entrez gene/locuslink") {
                    if($2 =~ m/^\d+$/) {
                        $gene2->addSecondaryID($2, "Entrez");
                    }
                    else {
                        $gene2->addSecondaryID($2, "Symbol");
                    }
                }
                elsif(exists($db_map{lc($1)})) {
                    $gene2->addSecondaryID($2, $db_map{lc($1)});
                }
            }

            # Get Detection Method
            my $detection_method = ($fields[6] =~ /(MI:\d{4})/)[0];

            # Get Interaction Type
            my $interaction_type = ($fields[11] =~ /(MI:\d{4})/)[0];

            # Get PubMed IDs
            my @pmids = $fields[8] =~ /pubmed:(\d+)/g;

            # Insert interactions
            $self->insertInteraction($gene1, $gene2, $detection_method, $interaction_type, \@pmids)
        }
        close $IN;
        $self->log("\n");
    }
    print "\n";
}

main();
