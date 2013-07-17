CREATE FUNCTION recurrences_for(
	range_start DATETIME,
	range_end DATETIME,
	event_id INT(1),
	event_starts_on DATE,
	event_ends_on DATE,
	event_starts_at DATETIME,
	event_ends_at DATETIME,
	event_frequency ENUM ('daily', 'weekly', 'monthly', 'yearly'),
	event_separation TINYINT(1),
	event_count TINYINT(1),
	event_until DATE
)
RETURNS TINYINT(1)
DETERMINISTIC
CONTAINS SQL
BEGIN
	DECLARE recurrence_day TINYINT(1);
	DECLARE recurrence_week TINYINT(1);
	DECLARE recurrence_month TINYINT(1);
	DECLARE recurrences_start DATE;
	DECLARE recurrences_end DATE;
	DECLARE duration VARCHAR(30);
	DECLARE duration_expression TINYINT(1);
	DECLARE duration_unit ENUM ('day', 'week', 'month', 'year');
	DECLARE next_date DATE;
	DECLARE no_more_rows BOOLEAN DEFAULT FALSE;
	
	# Left join in this query will populate all values with NULL rather than skipping it if event_id not found
	DECLARE event_recurrences_cursor CURSOR FOR 
		SELECT `day`, `week`, `month`
			FROM (SELECT NULL) AS `foo`
			LEFT JOIN `event_recurrences`
				ON `event_recurrences`.`event_id` = event_id;
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_more_rows := TRUE;
	
	SET recurrences_start := COALESCE(DATE(event_starts_at), event_starts_on), recurrences_end := range_end, duration := interval_for(event_frequency), duration_expression := split_string(duration, ' ', 1) * event_separation, duration_unit = split_string(duration, ' ', 2), duration := CONCAT(duration_expression, ' ', duration_unit);
	
	IF event_until IS NOT NULL AND event_until < recurrences_end THEN
		SET recurrences_end := event_until;
	END IF;
	
	IF event_count IS NOT NULL AND date_variable_add(recurrences_start, (event_count - 1) * duration_expression, duration_unit) < recurrences_end THEN
		SET recurrences_end := date_variable_add(recurrences_start, (event_count - 1) * duration_expression, duration_unit);
	END IF;
	
	OPEN event_recurrences_cursor;
	
	the_loop: LOOP
		FETCH event_recurrences_cursor INTO recurrence_day, recurrence_week, recurrence_month;
		
		IF no_more_rows THEN
			CLOSE event_recurrences_cursor;
			LEAVE the_loop;
		END IF;

		# Recurrences generated are inserted into Temporary Table of the name temporary_table_recurring_dates
		SET @temp := generate_recurrences_test(
			duration,
			recurrences_start,
			COALESCE(DATE(event_ends_at), event_ends_on),
			DATE(range_start),
			recurrences_end,
			recurrence_day,
			recurrence_week,
			recurrence_month
		);
		
		IF recurrence_day IS NULL AND recurrence_week IS NULL AND recurrence_month IS NULL THEN
			SET no_more_rows := TRUE;
		END IF;
		
	END LOOP the_loop;
	
	RETURN TRUE;
END;