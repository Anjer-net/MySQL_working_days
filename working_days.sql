--  (c) 2024 Anjer Apps
--   Jeroen Meintjens
--    www.anjer.net
--     version 1.0


-- -- Create table for specified holidays -- --
CREATE TABLE `holidays` (
	`date` date NOT NULL,
	`type` varchar(32) NOT NULL,
	`category` varchar(30) DEFAULT NULL,
	`day_off` tinyint(1) NOT NULL DEFAULT 1,
	`weekday` tinyint(3) unsigned GENERATED ALWAYS AS (WEEKDAY(`date`)) STORED,
	PRIMARY KEY (`date`,`type`),
	KEY `date` (`date`),
	KEY `type` (`type`),
	KEY `day_off` (`day_off`),
	KEY `weekday` (`weekday`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
	COMMENT='@Anjer_Apps https://github.com/Anjer-net/MySQL_working_days ';

-- -- Functions -- -- 
-- Count weekdays (Mo/Tu/We/Th/Fr) between two dates (inclusive) 
CREATE FUNCTION `calculate_weekdays`(`date1` DATE, `date2` DATE) RETURNS smallint(11)
	COMMENT '@peterm https://stackoverflow.com/questions/18302181/ ' 
RETURN (1
	+ ABS(DATEDIFF(date2, date1))
	- ABS(DATEDIFF(ADDDATE(date2, INTERVAL 1 - DAYOFWEEK(date2) DAY),
				ADDDATE(date1, INTERVAL 1 - DAYOFWEEK(date1) DAY))) / 7 * 2
	- (DAYOFWEEK(IF(date1 < date2, date1, date2)) = 1)
	- (DAYOFWEEK(IF(date1 > date2, date1, date2)) = 7)
);

-- Count holidays during weekdays (Mo/Tu/We/Th/Fr)
CREATE FUNCTION `holidays_count_weekdays_off`(`From` DATE, `To` DATE) RETURNS smallint(11)
	COMMENT '@Anjer_Apps https://github.com/Anjer-net/MySQL_working_days '
RETURN (
    SELECT COUNT(DISTINCT `date`) 
    FROM `holidays` 
    WHERE `day_off`=1
    	AND `weekday` <5
    	AND `date`>=`From` 
    	AND `date`<=`To`
);

-- Calculate working days (Mo/Tu/We/Th/Fr minus free holidays) between two dates (inclusive) 
CREATE FUNCTION `calculate_working_days`(`From` DATE, `To` DATE) RETURNS smallint(11)
	COMMENT '@Anjer_Apps https://github.com/Anjer-net/MySQL_working_days '
RETURN (
    calculate_weekdays(`From`, `To`) - holidays_count_weekdays_off(`From`, `To`)
);

-- Calculate Easter
DELIMITER $$
CREATE FUNCTION `calculate_easter`(`Y` YEAR) RETURNS date
    COMMENT '@jweiher https://github.com/jweiher/mysql-easter/blob/master/easter.sql '
BEGIN
	DECLARE K,M,S,A,D,R,OG,SZ,OE,OS INT;
	DECLARE Easterdate DATE;
	SET K = Y DIV 100;
	SET M = 15 + (3*K + 3) DIV 4 - (8*K + 13) DIV 25;
	SET S = 2 - (3*K + 3) DIV 4;
	SET A = Y MOD 19;
	SET D = (19*A + M) MOD 30;
	SET R = (D + A DIV 11) DIV 29;
	SET OG = 21 + D - R ;
	SET SZ = 7 - (Y + Y DIV 4 + S) MOD 7;
	SET OE = 7 - (OG - SZ) MOD 7;
	SET OS = OG + OE;
	SET Easterdate = date_add(concat(Y, '-03-01'), INTERVAL OS-1 DAY);
RETURN Easterdate;
END$$
DELIMITER ;

-- -- Insert data -- -- 
-- Nieuwjaarsdag New Year's Day
INSERT INTO `holidays` (`date`, `type`, `category`) 
	SELECT STR_TO_DATE( CONCAT('1 1 ', `seq`), '%d %m %Y'), 'Nieuwjaarsdag', 'Intl'
	FROM `seq_1901_to_2099`;

-- Kerstmis / Christmas / Boxing Day
INSERT INTO `holidays` (`date`, `type`, `category`) 
	SELECT STR_TO_DATE( CONCAT('25 12 ', `seq`), '%d %m %Y'), 'Eerste kerstdag', 'Christian'
	FROM `seq_1901_to_2099`;
INSERT INTO `holidays` (`date`, `type`, `category`) 
	SELECT STR_TO_DATE( CONCAT('26 12 ', `seq`), '%d %m %Y'), 'Tweede kerstdag', 'Christian'
	FROM `seq_1901_to_2099`;
	
-- Pasen / Eerste Paasdag / Easter
INSERT INTO `holidays` (`date`, `type`, `category`) 
	SELECT calculate_easter(`seq`), 'Eerste paasdag', 'Christian'
	FROM `seq_1901_to_2099`;
	
-- Tweede Paasdag / Easter Monday
INSERT INTO `holidays` (`date`, `type`, `category`, `day_off`) 
	SELECT (`date` + INTERVAL 1 DAY), 'Tweede paasdag', 'Christian', 1
	FROM `holidays`
	WHERE `holidays`.`type` = 'Eerste paasdag';

-- Goede Vrijdag / Good Friday
INSERT INTO `holidays` (`date`, `type`, `category`, `day_off`) 
	SELECT (`date` - INTERVAL 2 DAY), 'Goede vrijdag', 'Christian', 0
	FROM `holidays`
	WHERE `holidays`.`type` = 'Eerste paasdag';

-- Hemelvaart / Ascension Day
INSERT INTO `holidays` (`date`, `type`, `category`, `day_off`) 
	SELECT (`date` + INTERVAL 39 DAY), 'Hemelvaart', 'Christian', 1
	FROM `holidays`
	WHERE `holidays`.`type` = 'Eerste paasdag';

-- Pinksteren / Eerste Pinksterdag / Pentecost / Whit Sunday
INSERT INTO `holidays` (`date`, `type`, `category`, `day_off`) 
	SELECT (`date` + INTERVAL 49 DAY), 'Eerste pinksterdag', 'Christian', 1
	FROM `holidays`
	WHERE `holidays`.`type` = 'Eerste paasdag';

-- Tweede Pinksterdag / Whit Monday
INSERT INTO `holidays` (`date`, `type`, `category`, `day_off`) 
	SELECT (`date` + INTERVAL 50 DAY), 'Tweede pinksterdag', 'Christian', 1
	FROM `holidays`
	WHERE `holidays`.`type` = 'Eerste paasdag';

-- NL Koningsdag
INSERT INTO `holidays` (`date`, `type`, `category`) 
	SELECT 
		IF( 
			WEEKDAY(STR_TO_DATE( CONCAT('27 4 ', `seq`), '%d %m %Y'))=6, # never on sunday
			STR_TO_DATE( CONCAT('26 4 ', `seq`), '%d %m %Y'), # then saturday april 26
			STR_TO_DATE( CONCAT('27 4 ', `seq`), '%d %m %Y')
		), 
		'Koningsdag', 
		'NL'
	FROM `seq_2014_to_2067`;

-- NL Bevrijdingsdag / Liberation Day
INSERT INTO `holidays` (`date`, `type`, `category`, `day_off`) 
	SELECT 
		STR_TO_DATE( CONCAT('5 5 ', `seq`), '%d %m %Y'),
		'Bevrijdingsdag', 
		'NL',
		IF(`seq` > 1990 AND `seq` MOD 5, 0, 1) # Since 1990 only every 5th year day off
	FROM `seq_1946_to_2099`;
