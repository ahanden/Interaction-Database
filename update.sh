#!/bin/bash

# Get user data
# echo -n "Username: "
# read USER
# echo -n "Password: "
# read -s PASS
# echo

echo "Updating HPRD"
perl hprd.pl /home/HandenA/data/HPRD/FLAT_FILES_072010/BINARY_PROTEIN_PROTEIN_INTERACTIONS.txt -v < auth > /dev/null 

echo "Updating CORUM"
perl corum.pl /home/HandenA/data/CORUM/allComplexes.csv -v < auth > /dev/null

echo "Updating MINT"
perl mitab.pl /home/HandenA/data/MINT/2013-03-26-mint-full-binary.mitab26.txt -v < auth > /dev/null

echo "Updating MINT Complexes"
perl mitab.pl /home/HandenA/data/MINT/2013-03-26-mint-full-complexes.mitab26.txt -v < auth > /dev/null

echo "Updating IntAct"
perl mitab.pl /home/HandenA/data/intact/intact.txt -v < auth > /dev/null

echo "Updating BioGRID"
perl mitab.pl /home/HandenA/data/BioGRID/BIOGRID-ALL-3.4.135.mitab.txt -v < auth > /dev/null

echo "Updating PhosphoSite"
perl phosphosite.pl /home/HandenA/data/phosphosite/Kinase_Substrate_Dataset -v < auth > /dev/null

echo "Updating Rual et. al."
perl tsv.pl /home/HandenA/data/rual_et_al.tsv -v < auth > /dev/null

# Note - this update should be removed once the paper is included in the BioGRID download
echo "Updating Huttlin et. al."
perl tsv.pl /home/HandenA/data/huttlin_et_al.tsv -v < auth > /dev/null
