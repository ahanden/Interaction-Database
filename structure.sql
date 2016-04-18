DROP TABLE IF EXISTS `interactions`;
CREATE TABLE `interactions` (
	`entrez_id1` int(10) unsigned NOT NULL,
	`entrez_id2` int(10) unsigned NOT NULL,
	PRIMARY KEY (`entrez_id1`,`entrez_id2`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
