#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
use XML::Parser;
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
        'sp'                     => 'UniProt',
        'trembl'                 => 'UniProt',
        'uniprot'                => 'UniProt',
        'uniprotkb'              => 'UniProt',
        'uniprot knowledge base' => 'UniProt',
        'uniprot/swiss-prot'     => 'UniProt',
        'uniprot/trembl'         => 'UniProt',
        'entrezgene'             => 'Entrez',
        'entrez gene/locuslink'  => 'Entrez',
        'ensembl'                => 'Ensembl',
        'hprd'                   => 'HPRD',
        'hgnc'                   => 'HGNC:HGNC',
        'tair'                   => 'TAIR',

    );

    # Tracking Variables
    my %interaction = (
        experiments  => [],
        participants => []
    );

    my %experimentList = ();

    my %experiment = (
        pmids => [],
        det_type => ''
    );

    my %geneList = ();

    my $gene = Gene->new();

    my $int_count = 0;

    my $self_handle;

    sub checkArgs {
        my $self = shift;

        my ($verbose, $int_cnf, $gen_cnf);
        if(GetOptions('verbose' => \$verbose, 'interactions_cnf=s' => \$int_cnf, 'genes_cnf=s' => \$gen_cnf)  && @ARGV == 1) {
            $self->{fname}    = $ARGV[0];
            $self->{cnf_file} = $int_cnf or die "You must provide a cnf file for access to the interactions database\n";
            $self->{gen_cnf}  = $gen_cnf or die "You must provide a cnf file for access to the genes database\n";
            $self->{verbose}  = $verbose;

            Gene::connectDB($self->{gen_cnf});

            return 1;
        }
        return 0;
    }

    sub tagStart {
        my $expat = shift;
        my $element = shift;
        my %attr = @_;

        # Experiment/Source data
        if($element eq "experimentDescription" && exists($attr{id})) {
            $experiment{id} = $attr{id};
        }
        elsif($expat->within_element("experimentDescription")) {
            # Publication data
            if($expat->within_element("bibref") && 
                    exists($attr{db}) &&
                    exists($attr{id}) && 
                    "pubmed" eq lc($attr{db}) ) {
                push(@{$experiment{pmids}}, split(",",$attr{id}));
            }
            # Detection method
            elsif(($expat->within_element("interactionDetection") || $expat->within_element("interactionDetectionMethod")) &&
                    exists($attr{db}) &&
                    exists($attr{id}) &&
                    ("mi" eq lc($attr{db}) || "psi-mi" eq lc($attr{db}))) {
                if($attr{id} !~ m/MI:\d+/) { $experiment{det_type} = "MI:".$attr{id}; }
                else { $experiment{det_type} = $attr{id}; }
            }
        }

        # Interaction type
        elsif($expat->within_element("interactionType") && exists($attr{id})) {
            if(exists($interaction{type})) {
                print "Ooops\n";
            }
            $interaction{type} = $attr{id};
        }

        # Interactors
        elsif($element eq "interactor" && exists($attr{id})) {
            $gene->{id} = $attr{id};
        }
        elsif($expat->within_element("interactor") || $expat->within_element("proteinParticipant")) {
            if($element eq "organism") {
                $gene->setOrganism($attr{ncbiTaxId});
            }
            elsif($element eq "primaryRef" && exists($db_map{lc($attr{db})})) {
                $gene->setPrimaryID($attr{id},$db_map{lc($attr{db})});
            }
            elsif($element eq "secondaryRef" && exists($db_map{lc($attr{db})})) {
                $gene->addSecondaryID($attr{id}, $db_map{lc($attr{db})});
            }
        }
    }

    sub tagEnd {
        my ($expat, $element) = @_;
        #$self_handle->log("Line ".$expat->current_line()."/$self_handle->{prog_total} ($int_count interactions)\r");

        # Add an experiment
        if($element eq "experimentDescription") {
            my %pointer = %experiment;

            if($expat->within_element("interaction")) {
                push(@{$interaction{experiments}}, \%pointer);
            }

            if(exists($experiment{id})) {
                $experimentList{$experiment{id}} = \%pointer;
            }

            %experiment = (
                pmids => [],
                det_type => ''
            );

        }

        # Add an interactor
        elsif($element eq "interactor" || $element eq "proteinParticipant") {
            my $pointer = $gene;
            if(exists($gene->{id})) {
                $geneList{$gene->{id}} = $pointer; 
            }
            if($expat->within_element("interaction")) {
                push(@{$interaction{participants}}, $pointer);
            }

            $gene = Gene->new();


        }

        # Add an interaction
        elsif($element eq "interaction" && $interaction{participants}) {
            my @participants = @{$interaction{participants}};

            for(my $i = 0; $i < @participants; $i++) {
                next unless $participants[$i]->{organism} == 9606;
                foreach(my $j = $i + 1; $j < @participants; $j++) {
                    next unless $participants[$j]->{organism} == 9606;
                    if(@{$interaction{experiments}}) {
                        foreach my $experiment(@{$interaction{experiments}}) {
                            $int_count += $self_handle->insertInteraction($participants[$i], $participants[$j], $experiment->{det_type}, $interaction{type}, $experiment->{pmids});
                        }
                    }
                    else {
                        $int_count += $self_handle->insertInteraction($participants[$i], $participants[$j]);
                    }
                }
            }


            %interaction = (
                experiments => [],
                participants => []
            );
        }
    }

    sub tagContent {
        my($expat, $string) = @_;

        # Add an experiment reference
        if($expat->within_element("interaction") && $expat->within_element("experimentRef")) {
            push(@{$interaction{experiments}}, $experimentList{$string});
        }

        # Add an interactor reference
        elsif($expat->within_element("participantList") && $expat->in_element("interactorRef") && exists($geneList{$string})) {
            push(@{$interaction{participants}}, $geneList{$string});
        }
    }

    sub exec_main {
        my $self=shift;

        $self_handle = $self;

        my $fname = $ARGV[0];

        my $parser = new XML::Parser(Handlers => {
            Start => \&tagStart,
            End   => \&tagEnd,
            Char  => \&tagContent});

        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;
        $parser->parsefile($fname);
    }
}

main();
