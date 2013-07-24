--
-- Table structure for table `events`
--

CREATE TABLE IF NOT EXISTS `events` (
  `id` int(1) NOT NULL AUTO_INCREMENT,
  `starts_on` date DEFAULT NULL,
  `ends_on` date DEFAULT NULL,
  `starts_at` datetime DEFAULT NULL,
  `ends_at` datetime DEFAULT NULL,
  `frequency` enum('once','daily','weekly','monthly','yearly') NOT NULL,
  `separation` tinyint(1) unsigned NOT NULL DEFAULT '1',
  `count` tinyint(1) DEFAULT NULL,
  `until` date DEFAULT NULL,
  `timezone_name` varchar(255) NOT NULL DEFAULT 'Etc/UTC',
  `status` tinyint(1) NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `event_cancellations`
--

CREATE TABLE IF NOT EXISTS `event_cancellations` (
  `id` int(1) NOT NULL AUTO_INCREMENT,
  `event_id` int(1) NOT NULL,
  `date` date NOT NULL,
  PRIMARY KEY (`id`),
  KEY `event_id` (`event_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `event_recurrences`
--

CREATE TABLE IF NOT EXISTS `event_recurrences` (
  `id` int(1) NOT NULL AUTO_INCREMENT,
  `event_id` int(1) NOT NULL,
  `day` tinyint(1) NOT NULL,
  `week` tinyint(1) DEFAULT NULL,
  `month` tinyint(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `event_id` (`event_id`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `event_cancellations`
--
ALTER TABLE `event_cancellations`
  ADD CONSTRAINT `FK_event_id3` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`);

--
-- Constraints for table `event_recurrences`
--
ALTER TABLE `event_recurrences`
  ADD CONSTRAINT `FK_event_id2` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`);