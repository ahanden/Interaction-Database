#!/bin/bash

# So the SignalLink people have *no* idea how to format a MI-TAB file,
# and screw up most of the identifier labels. This script is meant to
# correct those labels.

fname=$1

# They forgot a bar dilimiter for some of the entries
sed -i 's/\Sentrez gene/|entrez gene/g' $fname

# They mislabeled Ensembl genes as Entrez genes
sed -i 's!entrez gene/locuslink:ENSG!ensembl:ENSG!g' $fname

# They also mislabled mirBase genes as uniprot
sed -i 's/uniprotkb:\(MI[0-9]\{7\}\)/mirbase:\1/g' $fname
