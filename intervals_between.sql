CREATE FUNCTION intervals_between(
	start_date DATE, # Example: 2013-07-01
	end_date DATE, # Example: 2013-07-02
	duration VARCHAR(30) # Examples: '1 day', '2 months', '3 years'
)
RETURNS INT(1)
DETERMINISTIC
CONTAINS SQL
BEGIN
	DECLARE count FLOAT(10, 3);
	DECLARE multiplier TINYINT(1);
	DECLARE duration_expression TINYINT(1);
	DECLARE duration_unit ENUM ('day', 'week', 'month', 'year');
	
	SET count := 0, multiplier := 512, duration_expression = split_string(duration, ' ', 1), duration_unit = split_string(duration, ' ', 2);
	
	IF start_date < end_date THEN
		the_loop: LOOP
			while_loop: WHILE date_variable_add(start_date, (count + multiplier) * duration_expression, duration_unit) < end_date DO
				SET count := count + multiplier;
			END WHILE while_loop;
			
			IF multiplier = 1 THEN
				LEAVE the_loop;
			END IF;
			
			SET multiplier := multiplier / 2;
		END LOOP the_loop;
		
		SET count := count +  (UNIX_TIMESTAMP(end_date) - UNIX_TIMESTAMP(date_variable_add(start_date, count * duration_expression, duration_unit))) / (UNIX_TIMESTAMP(date_variable_add(end_date, duration_expression, duration_unit)) - UNIX_TIMESTAMP(end_date));
	END IF;
	
	RETURN FLOOR(count);
END;