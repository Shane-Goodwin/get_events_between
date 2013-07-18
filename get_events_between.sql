CREATE PROCEDURE get_events_between(
	range_start DATETIME,
	range_end DATETIME,
	#time_zone VARCHAR(255),
	events_limit INT
)
DETERMINISTIC
MODIFIES SQL DATA
block1: BEGIN
	DECLARE original_date DATE;
	#DECLARE original_date_in_zone DATE;
	DECLARE start_time TIME;
	#DECLARE start_time_in_zone TIME;
	DECLARE end_time TIME;
	#DECLARE end_time_in_zone TIME;
	DECLARE the_next_date DATE;
	#DECLARE next_time_in_zone TIME;
	#DECLARE time_offset VARCHAR(255);
	DECLARE duration VARCHAR(10);
	DECLARE duration_expression TINYINT(1);
	DECLARE duration_unit ENUM ('day', 'week', 'month', 'year');
	DECLARE count_limit INT(1);
	
	#DECLARE recurrences_start DATE := CASE WHEN (timezone('UTC', range_start) AT TIME ZONE time_zone) < range_start THEN (timezone('UTC', range_start) AT TIME ZONE time_zone)::date ELSE range_start END;
	#DECLARE recurrences_end DATE := CASE WHEN (timezone('UTC', range_end) AT TIME ZONE time_zone) > range_end THEN (timezone('UTC', range_end) AT TIME ZONE time_zone)::date ELSE range_end END;
	DECLARE recurrences_start DATETIME;
	DECLARE recurrences_end DATETIME;
	
	DECLARE no_more_event_rows BOOLEAN DEFAULT FALSE;
	DECLARE no_more_recurrence_rows BOOLEAN DEFAULT FALSE;
	
	# Event variables for events_cursor
	DECLARE event_id INT(1);
	DECLARE event_starts_on DATE;
	DECLARE event_ends_on DATE;
	DECLARE event_starts_at DATETIME;
	DECLARE event_ends_at DATETIME;
	DECLARE event_frequency VARCHAR(20);
	DECLARE event_separation TINYINT(1);
	DECLARE event_count INT(1);
	DECLARE event_until DATE;
	DECLARE event_timezone_name VARCHAR(255);
	
	DECLARE events_cursor CURSOR FOR 
		SELECT id, starts_on, ends_on, starts_at, ends_at, frequency, separation, count, until, timezone_name
			FROM `events` 
			WHERE 
				(
					`frequency` <> 'once' AND
					`until` IS NULL OR `until` > DATE(range_start)
				)
				OR 
				(
					`frequency` = 'once' AND
					# Skipping timezone conversion here because can't convert timezone due to required timezone tables not set
					#((starts_on IS NOT NULL AND ends_on IS NOT NULL AND starts_on <= DATE(CONVERT_TZ(range_end, 'UTC', time_zone)) AND ends_on >= DATE(CONVERT_TZ(range_start, 'UTC', time_zone))) OR
					#(starts_on IS NOT NULL AND starts_on <= DATE(CONVERT_TZ(range_end, 'UTC', time_zone)) AND starts_on >= DATE(CONVERT_TZ(range_start, 'UTC', time_zone))) OR
					(
						(`starts_on` IS NOT NULL AND `ends_on` IS NOT NULL AND `starts_on` <= DATE(range_end) AND `ends_on` >= DATE(range_start)) OR
						(`starts_on` IS NOT NULL AND `starts_on` <= DATE(range_end) AND `starts_on` >= DATE(range_start)) OR
						(`starts_at` <= range_end AND `ends_at` >= range_start)
					)
				);
	DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_more_event_rows := TRUE;
	
	# Create temporary table for events
	CREATE TEMPORARY TABLE temporary_table_events (
		id INT(1),
		starts_on DATE,
		ends_on DATE,
		starts_at DATETIME,
		ends_at DATETIME,
		frequency ENUM ('once', 'daily', 'weekly', 'monthly'),
		separation TINYINT(1),
		count INT(1),
		until DATE,
		timezone_name VARCHAR(255)
	);
	
	# Create temporary table for recurring dates
	CREATE TEMPORARY TABLE temporary_table_recurring_dates (
		next_date DATE
	);
	
	SET recurrences_start := range_start, recurrences_end := range_end;
	
	# Skipping this step because required timezone tables are not set
	#IF CONVERT_TZ(range_start, 'UTC', time_zone) < range_start THEN
	#	SET recurrences_start := DATE(CONVERT_TZ(range_start, 'UTC', time_zone));
	
	#IF CONVERT_TZ(range_end, 'UTC', time_zone) > range_end THEN
	#	SET recurrences_end := DATE(CONVERT_TZ(range_end, 'UTC', time_zone));
	
	OPEN events_cursor;
	
	get_events: LOOP
		FETCH events_cursor INTO event_id, event_starts_on, event_ends_on, event_starts_at, event_ends_at, event_frequency, event_separation, event_count, event_until, event_timezone_name;
		
		IF no_more_event_rows THEN
			CLOSE events_cursor;
			LEAVE get_events;
		END IF;
			
		IF event_frequency = 'once' THEN
			INSERT INTO temporary_table_events VALUES (
				event_id,
				event_starts_on,
				event_ends_on,
				event_starts_at,
				event_ends_at,
				event_frequency,
				event_separation,
				event_count,
				event_until,
				event_timezone_name
			);
			
			ITERATE get_events;
		END IF;

		# All-day event
		IF event_starts_on IS NOT NULL AND event_ends_on IS NULL THEN
			SET original_date := event_starts_on;
			SET duration := '1 DAY';
		
		# Multi-day event
		ELSEIF event_starts_on IS NOT NULL AND event_ends_on IS NOT NULL THEN
			SET original_date := event_starts_on;
			#SET duration := timezone(time_zone, event.ends_on) - timezone(time_zone, event.starts_on);
			SET duration := CONCAT(DATEDIFF(event_ends_on, event_starts_on),' DAY');
		
		# Timespan event
		ELSE
			SET original_date := DATE(event_starts_at);
			#SET original_date_in_zone := DATE(CONVERT_TZ(event_starts_at, 'UTC', time_zone));
			SET start_time := TIME(event_starts_at);
			#SET start_time_in_zone := TIME(CONVERT_TZ(event_starts_at, 'UTC', time_zone));
			SET end_time := TIME(event_ends_at);
			#SET end_time_in_zone := TIME(CONVERT_TZ(event_ends_at, 'UTC', time_zone));
			#SET duration := event.ends_at - event.starts_at;
			SET duration := CONCAT(DATEDIFF(event_ends_at, event_starts_at), ' DAY');
		END IF;

		IF event_count IS NOT NULL THEN
			SET recurrences_start := original_date;
			SET count_limit := event_count;
		ELSE
			SET count_limit := 999999;
		END IF;
		
		# Split duration into expression and unit
		SET duration_expression := split_string(duration, ' ', 1), duration_unit = split_string(duration, ' ', 2);
		
		# Reset no_more_recurrence_rows back to FALSE
		SET no_more_recurrence_rows := FALSE;
		
		# Reset temporary table of recurrences to only contain this event's recurrences
		TRUNCATE temporary_table_recurring_dates;
                    
        # Insert all recurring dates for event into temporary_table_recurring_dates
		SET @temp := recurrences_for(
			recurrences_start,
			recurrences_end,
			event_id,
			event_starts_on,
			event_ends_on,
			event_starts_at,
			event_ends_at,
			event_frequency,
			event_separation,
			count_limit,
			event_until
		);
		
		# Also insert original date of event into temporary_table_recurring_dates
		INSERT INTO temporary_table_recurring_dates (next_date) VALUES (original_date);
		
		block2: BEGIN
			DECLARE recurrences_cursor CURSOR FOR
				SELECT next_date
					FROM `temporary_table_recurring_dates`
					WHERE
						`next_date` <= recurrences_end AND
						date_variable_add(`next_date`, duration_expression, duration_unit) >= recurrences_start AND
						`next_date` NOT IN (
							SELECT `date` FROM `event_cancellations` WHERE `event_id` = event_id
						)
					LIMIT events_limit;
			DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_more_recurrence_rows := TRUE;
			
			OPEN recurrences_cursor;
			
			get_recurrences: LOOP
				FETCH recurrences_cursor INTO the_next_date;
				
				IF no_more_recurrence_rows THEN
					CLOSE recurrences_cursor;
					LEAVE get_recurrences;
				END IF;
				
				# All-day event
				IF event_starts_on IS NOT NULL AND event_ends_on IS NULL THEN
					# IF the_next_date < DATE(CONVERT_TZ(range_start, 'UTC', time_zone)) OR the_next_date > DATE(CONVERT_TZ(range_end, 'UTC', time_zone))
					IF the_next_date < range_start OR the_next_date > range_end THEN
						ITERATE get_recurrences;
					END IF;
					
					SET event_starts_on := the_next_date;
				
				# Multi-day event
				ELSEIF event_starts_on IS NOT NULL AND event_ends_on IS NOT NULL THEN
					SET event_starts_on := the_next_date;
					
					# IF event_starts_on > DATE(CONVERT_TZ(range_end, 'UTC', time_zone)) THEN
					IF event_starts_on > range_end THEN
						ITERATE get_recurrences;
					END IF;
					
					SET event_ends_on := date_variable_add(the_next_date, duration_expression, duration_unit);
					
					# IF event_ends_on < DATE(CONVERT_TZ(range_start, 'UTC', time_zone)) THEN
					IF event_ends_on < range_start THEN
						ITERATE get_recurrences;
					END IF;
				
				# Timespan event
				ELSE
					#SET next_time_in_zone := TIME(CONVERT_TZ(the_next_date + start_time, 'UTC', event_timezone_name));
					#SET time_offset := (original_date_in_zone + next_time_in_zone) - (original_date_in_zone + start_time_in_zone);
					#SET event_starts_at := the_next_date + start_time - time_offset;
                    SET event_starts_at := TIMESTAMP(the_next_date, start_time);
                    
					IF event_starts_at > range_end THEN
						ITERATE get_recurrences;
					END IF;
					
					SET event_ends_at := TIMESTAMP(date_variable_add(event_starts_at, duration_expression, duration_unit), end_time);
					
					IF event_ends_at < range_start THEN
						ITERATE get_recurrences;
					END IF;
				END IF;
				
				INSERT INTO temporary_table_events VALUES (
					event_id,
					event_starts_on,
					event_ends_on,
					event_starts_at,
					event_ends_at,
					event_frequency,
					event_separation,
					event_count,
					event_until,
					event_timezone_name
				);
				
			END LOOP get_recurrences;
			
		END block2;
		
	END LOOP get_events;
	
	# Return rows from temporary_table_events
	SELECT *, COALESCE(`starts_on`, `starts_at`) as `event_start` FROM `temporary_table_events`;
                    
	DROP TEMPORARY TABLE IF EXISTS temporary_table_events;
	DROP TEMPORARY TABLE IF EXISTS temporary_table_recurring_dates;
END block1;