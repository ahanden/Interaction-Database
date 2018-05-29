DROP TABLE IF EXISTS `interactions`;
CREATE TABLE `interactions` (
	`int_id`     int(10) unsigned NOT NULL AUTO_INCREMENT,
	`entrez_id1` int(10) unsigned NOT NULL,
	`entrez_id2` int(10) unsigned NOT NULL,
	PRIMARY KEY (`entrez_id1`, `entrez_id2`),
	KEY(int_id)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `sources`;
CREATE TABLE `sources` (
	`int_id`           int(10) unsigned NOT NULL,
	`pubmed_id`        int unsigned NOT NULL,
	`detection_method` varchar(7),
	`int_type`         varchar(7),
	UNIQUE KEY (`int_id`, `pubmed_id`, `detection_method`, `int_type`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

DROP TABLE IF EXISTS `psimi`;
CREATE TABLE `psimi` (
	`id`	varchar(7),
	`name`	varchar(255),
	`description`	varchar(255),
	PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
