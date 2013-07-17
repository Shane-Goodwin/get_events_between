CREATE FUNCTION generate_recurrences(
	duration VARCHAR(30), # Examples: '1 day', '2 months', '3 years'
	original_start_date DATE, # Example: 2013-07-01
	original_end_date DATE, # Example: 2013-07-02
	range_start DATE, # Example: 2013-07-01
	range_end DATE, # Example: 2013-07-02
	repeat_day TINYINT(1),
	repeat_week TINYINT(1),
	repeat_month TINYINT(1)
)
RETURNS TINYINT(1)
DETERMINISTIC
CONTAINS SQL
BEGIN
	DECLARE start_date DATE;
	DECLARE duration_expression TINYINT(1);
	DECLARE duration_unit ENUM ('day', 'week', 'month', 'year');
	DECLARE next_date DATE;
	DECLARE intervals INT(1);
	DECLARE current_month TINYINT(1);
	DECLARE current_week TINYINT(1);
	
	SET start_date := original_start_date, duration_expression := split_string(duration, ' ', 1), duration_unit := split_string(duration, ' ', 2), intervals := intervals_between(original_start_date, range_start, duration);
	
	IF repeat_month IS NOT NULL THEN
		# Monthly Frequency
		SET start_date := DATE_ADD(start_date, INTERVAL (12 + repeat_month - MONTH(start_date)) % 12 MONTH);
	END IF;
	
	IF repeat_week IS NULL AND repeat_day IS NOT NULL THEN
		# Weekly frequency
		IF duration = '7 day' THEN
			SET start_date := DATE_ADD(start_date, INTERVAL (7 + repeat_day - (DAYOFWEEK(start_date) - 1)) % 7 DAY);
		# Daily frequency
		ELSE
			SET start_date := DATE_ADD(start_date, INTERVAL repeat_day - DAYOFMONTH(start_date) DAY);
		END IF;
	END IF;
	
	the_loop: LOOP
		SET next_date := date_variable_add(start_date, intervals * duration_expression, duration_unit);
		
		IF repeat_week IS NOT NULL AND repeat_day IS NOT NULL THEN
			SET current_month := MONTH(next_date);
			SET next_date := DATE_ADD(next_date, INTERVAL (7 + repeat_day - (DAYOFWEEK(next_date) - 1) % 7) DAY);
			
			IF MONTH(next_date) != current_month THEN
				SET next_date := DATE_SUB(next_date, INTERVAL 7 DAY);
			END IF;
			
			IF repeat_week > 0 THEN
				SET current_week := CEIL(DAYOFMONTH(next_date) / 7);
			ELSE
				SET current_week := -CEIL((1 + DAY(LAST_DAY(next_date)) - DAYOFMONTH(next_date)) / 7);
			END IF;
			
			SET next_date := DATE_ADD(next_date, INTERVAL (repeat_week - current_week) * 7 DAY);
		END IF;
		
		IF next_date > range_end THEN
			LEAVE the_loop;
		END IF;
		
		IF next_date >= range_start AND next_date >= original_start_date THEN
			INSERT INTO temporary_table_recurring_dates (next_date) VALUES (next_date);
		
		ELSEIF original_end_date IS NOT NULL AND range_start >= date_variable_add(original_start_date, intervals * duration_expression, duration_unit) AND range_start <= date_variable_add(original_end_date, intervals * duration_expression, duration_unit) THEN
			INSERT INTO temporary_table_recurring_dates (next_date) VALUES (next_date);
		END IF;
		
		SET intervals := intervals + 1;
	END LOOP the_loop;
	
	RETURN TRUE;
END;