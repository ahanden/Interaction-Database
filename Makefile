
# Variables
DATE ?= `date +%Y_%m_%d`
DATA_DIR ?= data

SPECIES=9606

all : DIP BioGRID CORUM InnateDB IntAct MINT MatrixDB
	DB=$$(grep -P "^database=" int.cnf | sed 's/^database=//'); \
	mysqldump --defaults-file=int.cnf $$DB > $(DATA_DIR)/backup.sql
	tar -cvf backup.$(DATE).tar $(DATA_DIR)/
	7z a backup.$(DATE).tar.7z backup.$(DATE).tar
	rm backup.$(DATE).tar
	rm -f gen.cnf
	rm -f int.cnf

# DIP
DIP : structure gen.cnf $(DATA_DIR)/dip.mitab.txt
	perl mitab.pl -i int.cnf -g gen.cnf $(DATA_DIR)/dip.mitab.txt
$(DATA_DIR)/dip.mitab.txt :
	@echo "Please find the URL for the most recent DIP release (ftp://handena98:pm236KBf@dip.doe-mbi.ucla.edu/)"
	@read -p "URL: " url; \
	wget $$url --output-document=$(DATA_DIR)/dip.mitab.txt

# BioGRID
BioGRID : structure gen.cnf $(DATA_DIR)/BIOGRID-ALL-LATEST.mitab.txt
	perl mitab.pl -i int.cnf -g gen.cnf $(DATA_DIR)/BIOGRID-ALL-LATEST.mitab.txt
$(DATA_DIR)/BIOGRID-ALL-LATEST.mitab.txt :
	wget http://thebiogrid.org/downloads/archives/Latest%20Release/BIOGRID-ALL-LATEST.mitab.zip --output-document=$(DATA_DIR)/BIOGRID-ALL-LATEST.mitab.zip
	unzip $(DATA_DIR)/BIOGRID-ALL-LATEST.mitab.zip -d $(DATA_DIR)
	rm $(DATA_DIR)/BIOGRID-ALL-LATEST.mitab.zip
	mv $(DATA_DIR)/BIOGRID-*.mitab.txt $(DATA_DIR)/BIOGRID-ALL-LATEST.mitab.txt

# CORUM
CORUM : structure gen.cnf $(DATA_DIR)/corum_psimi_release090109.xml
	perl mixml.pl -i int.cnf -g gen.cnf $(DATA_DIR)/corum_psimi_release090109.xml
$(DATA_DIR)/corum_psimi_release090109.xml :
	wget http://mips.helmholtz-muenchen.de/genre/export/sites/default/corum/allComplexes.psimi.zip --output-document=$(DATA_DIR)/allComplexes.psimi.zip
	unzip $(DATA_DIR)/allComplexes.psimi.zip -d $(DATA_DIR)
	rm $(DATA_DIR)/allComplexes.psimi.zip

# InnateDB
InnateDB : structure gen.cnf $(DATA_DIR)/innatedb_all.mitab
	perl mitab.pl -i int.cnf -g gen.cnf $(DATA_DIR)/innatedb_all.mitab
$(DATA_DIR)/innatedb_all.mitab :
	wget http://www.innatedb.com/download/interactions/innatedb_all.mitab.gz --output-document=$(DATA_DIR)/innatedb_all.mitab.gz
	gunzip $(DATA_DIR)/innatedb_all.mitab.gz

# IntAct
IntAct: structure gen.cnf $(DATA_DIR)/intact.txt $(DATA_DIR)/intact-micluster.txt
	perl mitab.pl -i int.cnf -g gen.cnf $(DATA_DIR)/intact.txt
	perl mitab.pl -i int.cnf -g gen.cnf $(DATA_DIR)/intact-micluster.txt
$(DATA_DIR)/intact.txt :
	wget ftp://ftp.ebi.ac.uk/pub/databases/intact/current/psimitab/intact.zip --output-document=$(DATA_DIR)/intact.zip
	unzip $(DATA_DIR)/intact.zip -d $(DATA_DIR)
	rm $(DATA_DIR)/intact.zip
	rm $(DATA_DIR)/intact_negative.txt
$(DATA_DIR)/intact-micluster.txt :
	wget ftp://ftp.ebi.ac.uk/pub/databases/intact/current/psimitab/intact-micluster.zip --output-document=$(DATA_DIR)/intact-micluster.zip
	unzip $(DATA_DIR)/intact-micluster.zip -d $(DATA_DIR)
	rm $(DATA_DIR)/intact-micluster.zip
	rm $(DATA_DIR)/intact-micluster_negative.txt

# MINT
MINT : structure gen.cnf $(DATA_DIR)/mint-full-binary.mitab26.txt $(DATA_DIR)/mint-full-complexes.mitab26.txt
	perl mitab.pl -i int.cnf -g gen.cnf $(DATA_DIR)/mint-full-binary.mitab26.txt 
	perl mitab.pl -i int.cnf -g gen.cnf $(DATA_DIR)/mint-full-complexes.mitab26.txt
$(DATA_DIR)/mint-full-binary.mitab26.txt :
	wget ftp://mint.bio.uniroma2.it/pub/release/mitab26/current/2013-03-26-mint-full-binary.mitab26.txt --output-document=$(DATA_DIR)/mint-full-binary.mitab26.txt
$(DATA_DIR)/mint-full-complexes.mitab26.txt :
	wget ftp://mint.bio.uniroma2.it/pub/release/mitab26/current/2013-03-26-mint-full-complexes.mitab26.txt --output-document=$(DATA_DIR)/mint-full-complexes.mitab26.txt

# MatrixDB
MatrixDB : structure gen.cnf $(DATA_DIR)/matrixdb_CORE.tab 
	perl mitab.pl -i int.cnf -g gen.cnf $(DATA_DIR)/matrixdb_CORE.tab
$(DATA_DIR)/matrixdb_CORE.tab :
	wget http://matrixdb.univ-lyon1.fr/download/matrixdb_CORE.tab.gz --output-document=$(DATA_DIR)/matrixdb_CORE.tab.gz
	gunzip $(DATA_DIR)/matrixdb_CORE.tab.gz

# Remove the data files
clean :
	rm -f $(DATA_DIR)/*
	rm -f int.cnf
	rm -f gen.cnf

# Apply the database structure
structure : int.cnf
	mysql --defaults-file=int.cnf < structure.sql

# Interaction database credentials
int.cnf :
	@echo "Interactions Database"
	@echo "---------------------"
	@echo "[client]" > int.cnf
	@read -p "Database: " db; echo "database=$$db" >> int.cnf
	@read -p "Username: " user; echo "user=$$user" >> int.cnf
	@read -s -p "Password: " passwd; echo "password=$$passwd" >> int.cnf
	@echo
	chmod 400 int.cnf

# Gene database credentials
gen.cnf :
	@echo "Genes Database"
	@echo "--------------"
	@echo "[client]" > gen.cnf
	@read -p "Database: " db; echo "database=$$db" >> gen.cnf
	@read -p "Username: " user; echo "user=$$user" >> gen.cnf
	@read -s -p "Password: " passwd; echo "password=$$passwd" >> gen.cnf
	@echo
	chmod 400 gen.cnf
