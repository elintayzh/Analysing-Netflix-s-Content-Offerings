-- DATA EXPLORATION
SELECT *
FROM netflix;

SELECT COUNT(*)
FROM netflix;

SELECT 
	COUNT(DISTINCT show_id),
	COUNT(DISTINCT type),
	COUNT(DISTINCT title),
	COUNT(DISTINCT director),
	COUNT(DISTINCT casts),
	COUNT(DISTINCT country),
	COUNT(DISTINCT date_added),
	COUNT(DISTINCT release_year),
	COUNT(DISTINCT rating),
	COUNT(DISTINCT duration),
	COUNT(DISTINCT listed_in),
	COUNT(DISTINCT description)
FROM netflix;

-- Checking for nulls

SELECT
	SUM(CASE WHEN show_id IS NULL THEN 1 ELSE 0 END) as show_id_nulls,
	SUM(CASE WHEN type IS NULL THEN 1 ELSE 0 END) as type_nulls,
	SUM(CASE WHEN director IS NULL THEN 1 ELSE 0 END) as director_nulls,
	SUM(CASE WHEN casts IS NULL THEN 1 ELSE 0 END) as casts_nulls,
	SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END) as country_nulls,
	SUM(CASE WHEN date_added IS NULL THEN 1 ELSE 0 END) as date_added_nulls,
	SUM(CASE WHEN release_year IS NULL THEN 1 ELSE 0 END) as release_year_nulls,
	SUM(CASE WHEN rating IS NULL THEN 1 ELSE 0 END) as rating_nulls,
	SUM(CASE WHEN duration IS NULL THEN 1 ELSE 0 END) as duration_nulls,
	SUM(CASE WHEN listed_in IS NULL THEN 1 ELSE 0 END) as listed_in_nulls,
	SUM(CASE WHEN description IS NULL THEN 1 ELSE 0 END) as description_nulls
FROM netflix;


-- DATA CLEANING

-- Ensuring that there are no duplicate show IDs
SELECT
	DISTINCT show_id,
	COUNT(*)
FROM netflix
GROUP BY show_id
HAVING COUNT(*) != 1;

-- fixing duration nulls
SELECT *
FROM netflix
WHERE duration IS NULL;

--- from this query, we see that for show_ids s5542, s5795, s5814, the durations are incorrectly inputed into the rating column instead.
--- we will fix this with an update to the table
UPDATE netflix
SET 
	duration = rating,
	rating = NULL
WHERE show_id IN ('s5542', 's5795', 's5814');

--- verify the updates
SELECT *
FROM netflix
WHERE show_id IN ('s5542', 's5795', 's5814');


-- Converting the date_added column to a column with date data type
--- adding a new column
ALTER TABLE netflix ADD COLUMN date_added_clean DATE;

--- updating the new column
UPDATE netflix
SET date_added_clean = TO_DATE(date_added, 'Month DD, YYYY');

--- verifying updates
SELECT date_added_clean
FROM netflix;


-- fixing date_added_nulls
SELECT *
FROM netflix
WHERE date_added IS NULL;

--- finding the median date diff between content release_year (assuming release date is 1st Jan of that year) and date_added
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY date_diff) AS median_date_diff
FROM (SELECT date_added_clean - CONCAT(release_year, '-01-01')::DATE AS date_diff 
		FROM netflix
		WHERE
		release_year IS NOT NULL AND 
		date_added_clean IS NOT NULL);

--- using this median date diff to inpute missing date_added values and adding them to date_added_clean column
WITH median_date_diff_table AS (
	SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY date_diff) AS median_date_diff
	FROM (SELECT date_added_clean - CONCAT(release_year, '-01-01')::DATE AS date_diff 
			FROM netflix
			WHERE
			release_year IS NOT NULL AND 
			date_added_clean IS NOT NULL)
)	

UPDATE netflix
SET date_added_clean = 
	CAST((CONCAT(release_year, '-01-01')::DATE + INTERVAL '1 day' * 
	median_date_diff_table.median_date_diff) AS DATE)
FROM median_date_diff_table
WHERE date_added IS NOT NULL AND date_added_clean IS NULL;

--- verifying that date_added_clean has no more missing values
SELECT COUNT(*)
FROM netflix
WHERE date_added_clean IS NULL;


-- fixing rating nulls
UPDATE netflix
SET rating = 'Unrated'
WHERE rating IS NULL;



-- ANALYSIS

-- 1. What content types dominate Netflix's catalogue?
SELECT
	type,
	COUNT(*) AS count_by_type,
	ROUND(COUNT(*)*100/SUM(COUNT(*)) OVER(), 2) AS percent_of_total
FROM netflix
GROUP BY type;


-- 2. What is the most common rating for TV shows and Movies?
SELECT
	type,
	rating
FROM
(SELECT
	type,
	rating,
	COUNT(*) as num_by_rating,
	RANK() OVER(PARTITION BY type ORDER BY COUNT(*) DESC) AS rank
FROM netflix
GROUP BY type, rating) AS subq
WHERE rank = 1;


-- 3. From which countries do most of Netflix's content come from currently?

-- to address combined values in the country column, we convert the string text in country column to array and unnesting the values, to effectively parse out the countries listed
SELECT 
	TRIM(UNNEST(STRING_TO_ARRAY(country, ','))) AS countries_new,
	COUNT(*) AS num_of_content
FROM netflix
GROUP BY countries_new
ORDER BY num_of_content DESC
LIMIT 5;


-- 4. What is the number of content items in each type of genre?
-- to address combined values in the listed_in column, we convert the string text in listed_in column to array, and unnesting the values, to effectively parse out the genres listed
SELECT 
	TRIM(UNNEST(STRING_TO_ARRAY(listed_in, ','))) AS genre_type,
	COUNT(*)
FROM netflix
GROUP BY genre_type
ORDER BY COUNT(*) DESC;


-- 5. Find the top 10 actors/ actresses by the number of movies on Netflix that they were in.
SELECT
	TRIM(UNNEST(STRING_TO_ARRAY(casts, ','))) AS actoractress,
	COUNT(*)
FROM netflix
WHERE type = 'Movie'
GROUP BY actoractress
ORDER BY COUNT(*) DESC
LIMIT 10;

