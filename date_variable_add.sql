CREATE FUNCTION date_variable_add(
	start_date DATE,
	duration_expression INT(1),
	duration_unit ENUM ('day', 'week', 'month', 'year')
)
RETURNS DATE
DETERMINISTIC
CONTAINS SQL
BEGIN
	DECLARE next_date DATE;
	
	CASE duration_unit
		WHEN 'day' THEN
			SET next_date := DATE_ADD(start_date, INTERVAL duration_expression DAY);
		
		WHEN 'week' THEN
			SET next_date := DATE_ADD(start_date, INTERVAL duration_expression WEEK);
		
		WHEN 'month' THEN
			SET next_date := DATE_ADD(start_date, INTERVAL duration_expression MONTH);
		
		ELSE # WHEN 'year' THEN
			SET next_date := DATE_ADD(start_date, INTERVAL duration_expression YEAR);
	END CASE;
	
	RETURN next_date;
END;