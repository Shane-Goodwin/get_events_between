CREATE FUNCTION interval_for(
	frequency ENUM ('daily', 'weekly', 'monthly', 'yearly')
)
RETURNS VARCHAR(10)
DETERMINISTIC
CONTAINS SQL
BEGIN
	DECLARE result VARCHAR(10);
	
	CASE frequency
		WHEN 'daily' THEN
			SET result := '1 DAY';
			
		WHEN 'weekly' THEN
			SET result := '7 DAY';
		
		WHEN 'monthly' THEN
			SET result := '1 MONTH';
		
		ELSE # WHEN 'yearly' THEN
			SET result := '1 YEAR';
	END CASE;
		
	RETURN result;
END;