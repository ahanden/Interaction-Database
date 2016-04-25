DROP TABLE IF EXISTS `interactions`;
CREATE TABLE `interactions` (
	`int_id`     int(10) unsigned NOT NULL AUTO_INCREMENT,
	`entrez_id1` int(10) unsigned NOT NULL,
	`entrez_id2` int(10) unsigned NOT NULL,
	PRIMARY KEY (`entrez_id1`,`entrez_id2`),
	KEY(int_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `publications`;
CREATE TABLE `publications` (
	`int_id`     int(10) unsigned NOT NULL,
	`pubmed_id`  int unsigned NOT NULL,
	PRIMARY KEY (`int_id`,`pubmed_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
