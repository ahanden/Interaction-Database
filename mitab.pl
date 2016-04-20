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
        if($other_id =~ m/entrez\s?gene\/locuslink:(\d+)/) {
            if(!exists($self->{eid_cache}->{eid})) {
                $self->{eid_cache}->{eid} = {};
            }
            if(!exists($self->{eid_cache}->{eid}->{$1})) {
                my @eids;
                $self->{eid_check}->execute($1);
                my $ref = $self->{eid_check}->fetch();
                if($ref->[0]) {
                    @eids = ($1);
                }
                else {
                    $self->{discontinued_query}->execute($1);
                    while(my $ref = $self->{discontinued_query}->fetch()) {
                        push(@eids,$ref->[0]);
                    }
                    #if(!@eids) {
                    #    print "Warning: Entrez ID $1 is not found in the database\n";
                    #}
                }
                $self->{eid_cache}->{eid}->{$1} = \@eids;
            }
            return $self->{eid_cache}->{eid}->{$1};
        }
        # Check for gene symbols
        elsif($other_id =~ m/entrez\s?gene\/locuslink:(.*)/){
            if(!exists($self->{eid_cache}->{symbol})) {
                $self->{eid_cache}->{symbol} = {};
            }
            if(!exists($self->{eid_cache}->{symbol}->{$1})) {
                my @eids;
                $self->{symbol_query}->execute($1);
                my $ref = $self->{symbol_query}->fetch();
                if($ref) {
                    @eids = ($ref->[0]);
                }
                else {
                    $self->{disc_symbol_query}->execute($1);
                    while(my $ref = $self->{disc_symbol_query}->fetch()) {
                        push(@eids,$ref->[0]);
                    }
                    if(!@eids) {
                        $self->{synonym_check}->execute($1);
                        while(my $ref = $self->{synonym_check}->fetch()) {
                            push(@eids,$ref->[0]);
                        }
                    }
                }
                $self->{eid_cache}->{symbol}->{$1} = \@eids;
            }
            return $self->{eid_cache}->{symbol}->{$1};
        }
        # Check for UniProt IDs
        elsif($other_id =~ m/uniprotkb:([OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2})/) {
            if(!exists($self->{eid_cache}->{uniprot})) {
                $self->{eid_cache}->{uniprot} = {};
            }
            if(!exists($self->{eid_cache}->{uniprot}->{$1})) {
                my @eids;
                $self->{cross_query}->execute('UniProt',$1);
                while(my $ref = $self->{cross_query}->fetch()) {
                    push(@eids,$ref->[0]);
                }
                $self->{eid_cache}->{uniprot}->{$1} = \@eids;
                #if(!@eids) {
                #    print "Warning: unable to find an Entrez ID for UniProt ID $1\n";
                #}
            }
            return $self->{eid_cache}->{uniprot}->{$1};
        }
        # Check for Ensembl IDs
        elsif($other_id =~ m/ensembl:(\w*?(E|FM|G|GT|P|R|T)\d+)/){
            if(!exists($self->{eid_cache}->{ensembl})) {
                $self->{eid_cache}->{ensembl} = {};
            }
            if(!exists($self->{eid_cache}->{ensembl}->{$1})) {
                my @eids;
                $self->{cross_query}->execute('Ensembl',$1);
                while(my $ref = $self->{fetch}) {
                    push(@eids,$ref->[0]);
                }
                #if(!@eids) {
                #    print "Warning: unable to find an Entrez ID for Ensembl ID $1\n";
                #}
                $self->{eid_cache}->{ensembl}->{$1} = \@eids;
            }
            return $self->{eid_cache}->{ensembl}->{$1};
        }
        # Check for miRBase IDs
        elsif($other_id =~ m/mirbase:(MI\d{7})/) {
            if(!exists($self->{eid_cache}->{mirbase})) {
                $self->{eid_cache}->{mirbase} = {};
            }
            if(!exists($self->{eid_cache}->{mirbase}->{$1})) {
                my @eids;
                $self->{cross_query}->execute('miRBase',$1);
                while(my $ref = $self->{fetch}) {
                    push(@eids,$ref->[0]);
                }
                #if(!@eids) {
                #    print "Warning: unable to find an Entrez ID for Ensembl ID $1\n";
                #}
                $self->{eid_cache}->{mirbase}->{$1} = \@eids;
            }
            return $self->{eid_cache}->{mirbase}->{$1};
        }
        elsif($other_id =~ m/tair:(AT[0-9]G[0-9]\{5\})/) {
            if(!exists($self->{eid_cache}->{tair})) {
                $self->{eid_cache}->{tair} = {};
            }
            if(!exists($self->{eid_cache}->{tair}->{$1})) {
                my @eids;
                $self->{tair_query}->execute('TAIR',$1);
                while(my $ref = $self->{fetch}) {
                    push(@eids,$ref->[0]);
                }
                #if(!@eids) {
                #    print "Warning: unable to find an Entrez ID for Ensembl ID $1\n";
                #}
                $self->{eid_cache}->{tair}->{$1} = \@eids;
            }
            return $self->{eid_cache}->{tair}->{$1};
        }
        # Any other label gets ignored
        return [];
    }

    sub exec_main {
        my $self = shift;

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";


        $self->{eid_cache} = {};
        #$self->{eid_check} = $self->{dbh}->prepare("SELECT EXISTS(SELECT * FROM genes.genes WHERE entrez_id = ? AND tax_id = 9606)");
        $self->{eid_check} = $self->{dbh}->prepare("SELECT EXISTS(SELECT * FROM genes.genes WHERE entrez_id = ?)");
        #$self->{discontinued_query} = $self->{dbh}->prepare("SELECT g.entrez_id FROM (SELECT entrez_id FROM genes.discontinued_genes WHERE discontinued_id = ?) AS d JOIN (SELECT entrez_id FROM genes.genes WHERE tax_id = 9606) AS g ON d.entrez_id = g.entrez_id");
        $self->{discontinued_query} = $self->{dbh}->prepare("SELECT entrez_id FROM genes.discontinued_genes WHERE discontinued_id = ?");
        #$self->{symbol_query} = $self->{dbh}->prepare("SELECT entrez_id FROM genes.genes WHERE symbol = ? AND tax_id = 9606");
        $self->{symbol_query} = $self->{dbh}->prepare("SELECT entrez_id FROM genes.genes WHERE symbol = ?");
        #$self->{synonym_check} = $self->{dbh}->prepare("SELECT g.entrez_id FROM (SELECT entrez_id FROM genes.gene_synonyms WHERE symbol = ?) AS s JOIN (SELECT entrez_id FROM genes.genes WHERE tax_id = 9606) AS g ON s.entrez_id = g.entrez_id");
        $self->{synonym_check} = $self->{dbh}->prepare("SELECT entrez_id FROM genes.gene_synonyms WHERE symbol = ?");
        #$self->{disc_symbol_query} = $self->{dbh}->prepare("SELECT g.entrez_id FROM (SELECT entrez_id FROM genes.discontinued_genes WHERE discontinued_symbol = ?) AS d JOIN (SELECT entrez_id FROM genes.genes WHERE tax_id = 9606) AS g ON d.entrez_id = g.entrez_id");
        $self->{disc_symbol_query} = $self->{dbh}->prepare("SELECT entrez_id FROM genes.discontinued_genes WHERE discontinued_symbol = ?");
        $self->{cross_query} = $self->{dbh}->prepare("SELECT entrez_id FROM genes.gene_xrefs WHERE Xref_db = ? AND Xref_id = ?");

        my $insert_query = $self->{dbh}->prepare("INSERT IGNORE INTO interactions(entrez_id1, entrez_id2) VALUES (?, ?)");


        $self->log("Checking file size...\n");
        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;
        my $count = 0;
        $self->log("Filling database...\n");
        while (my $line = <$IN>) {
            #$count ++;
            #print STDERR "$count/$total lines processed\r";
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
            foreach my $id(split(/\|/,"$fields[0]|$fields[2]")) {
                push(@eids1,@{getEIDs($self,$id)});
            }
            foreach my $id(split(/\|/,"$fields[1]|$fields[3]")) {
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

            # Insert interactions
            foreach my $gene1(@eids1) {
                foreach my $gene2(@eids2) {
                    next if $gene1 == $gene2;
                    if($gene1 > $gene2) {
                        ($gene1, $gene2) = ($gene2, $gene1);
                    }
                    $insert_query->execute($gene1, $gene2);
                }
            }
        }
        close $IN;
        $self->log("\n");
    }
    print "\n";
}

main();
