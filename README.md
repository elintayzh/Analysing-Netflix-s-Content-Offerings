# Table of Contents:

1. [**Methodology**](https://www.notion.so/Methodology-1f25e329588080f6bcbae201359634d3?pvs=21) 
2. [**Project Overview**](https://www.notion.so/Project-Overview-1f25e329588080e58eaffd7dadfb1f43?pvs=21) 
3. [**Data Exploration**](https://www.notion.so/Data-Exploration-1f25e329588080e2a178d013f24811f7?pvs=21) 
4. [**Data Cleaning**](https://www.notion.so/Data-Cleaning-1f25e329588080869d6ae71f9def751e?pvs=21) 
5. [**Data Analysis**](https://www.notion.so/Data-Analysis-1f25e329588080e8837bd11735194126?pvs=21) 
6. [**Findings and Insights**](https://www.notion.so/Findings-and-Insights-1f25e329588080f6bedeced045c473ef?pvs=21) 
7. [**Strategic Recommendations**](https://www.notion.so/Strategic-Recommendations-1f25e32958808081b356ddd21f750773?pvs=21) 
8. [**Limitations**](https://www.notion.so/Limitations-1f25e329588080c09c7fe320bac91adc?pvs=21) 
9. [**Next Steps and Project Advancement**](https://www.notion.so/Next-Steps-and-Project-Advancement-1f25e32958808059a8abe4da85f016b4?pvs=21) 

# **Analysing Netflix’s Content Offerings**

## **Methodology**

This project primarily used PostgreSQL for the following:

- Data Cleaning:
    - Addressed inconsistent and missing data
    - Used SQL functions to standardise data types (eg. date formats)
- Data Transformation:
    - Expanded and parsed comma-seperated fields for proper parsing and analysis
- Data Analysis
    - Used aggregate functions to summarise data by relevant dimensions
    - Used window functions to calculate row percentages
    - Used CTEs and subqueries to structure complex, multi-step queries

---

## **Project Overview**

Netflix is one of the world’s leading entertainment services, offering a vast catalogue of movies and TV shows on it’s platform, with over 8000 movies and TV shows as of mid-2021. 

Using a publicly available dataset on listing of content available on Netflix (as of mid-2021) this project uncovers content trends, genre popularity and other strategic insights. 

Using SQL, I performed data cleaning, data transformation and exploratory data analysis, with the goal of simulating how Netflix might use internal content data to inform strategic decisions on content acquisition, particularly focusing on content type, genre and geography.

---

## **Data Exploration**

Working with the data downloaded off Kaggle ([link](https://www.kaggle.com/datasets/shivamb/netflix-shows/data)), I imported the data into PostgreSQL and started exploring the raw data set using simple SQL queries. It is important to examine the unique values in the dataset, how the data is stored, and the column data types, as it lays a proper foundation for understanding of the data on hand. 

Using a simple `SELECT *` and `COUNT`query to understand the size of the data we have:

```sql
SELECT *
FROM netflix;

SELECT COUNT(*)
FROM netflix;
```

We also use a `COUNT(DISTINCT...)` function to understand the number of unique values I am dealing with in each column. This helps me identify columns that contain categorical data (eg. `type`, `rating`) versus those that are likely to contain free text or high-cardinality data (eg. `title`, `cast`, `country`). Understanding the uniqueness of values will inform how I might group or filter the data later during the analysis. 

```sql
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
```

It is also important to check for nulls in our data to evaluate data quality and identify any potential gaps that may impact analysis. The following query helps identity the number of null values in each column. I can then determine how we want to clean the data, or if data imputation is required before proceeding with the data analysis. 

```sql
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
```

---

## **Data Cleaning**

To start off the data cleaning process, I ensured that we do not have duplicate entries, using the `show_id` column to check for duplicates:

```sql
-- Ensuring that there are no duplicate show IDs
SELECT
	DISTINCT show_id,
	COUNT(*)
FROM netflix
GROUP BY show_id
HAVING COUNT(*) != 1;
```

During the data exploration process, I noticed a few null values in the duration column, as the values were wrongly inputted into another column. We will fix the null values using the following steps:

```sql
-- fixing duration nulls
SELECT *
FROM netflix
WHERE duration IS NULL;

--- from this query, we see that for show_ids s5542, s5795, s5814, the durations 
--- are incorrectly inputed into the rating column instead.
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
```

I also noted that the `date_added` column is not in SQL date-time format. To be able to do proper analysis using the `date_added` data, I decided to duplicate this column and transform the column to a proper date format:

```sql
-- Converting the date_added column to a column with date data type
--- adding a new column
ALTER TABLE netflix ADD COLUMN date_added_clean DATE;

--- updating the new column
UPDATE netflix
SET date_added_clean = TO_DATE(date_added, 'Month DD, YYYY');

--- verifying updates
SELECT date_added_clean
FROM netflix;
```

From the data exploration process, I also noticed a few null values within the `date_added` column (which indicates when the content is added into the Netflix platform), where `release_year` data was available. To address this, I decided to impute the missing values using the median difference between the `release_year` and `date_added` fields. 

The median was selected over the mean to reduce the influence of outliers, in cases when older content was added to Netflix many years post-release. For example, the film “Jaws” was released in 1975 (prior to Netflix’s existence), would skew the average if included in a mean calculation. 

```sql
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
```

Finally, fixing null values within the ratings column:

```sql
-- fixing rating nulls
UPDATE netflix
SET rating = 'Unrated'
WHERE rating IS NULL;
```

---

## **Data Analysis**

Once I had a better understanding of the data, I crafted business questions to guide my analysis, and crafted SQL queries to get the relevant insights

<aside>
💡

**Business Questions:**

1. What content types dominate Netflix's catalogue?
2. What is the most common rating for TV shows and Movies?
3. From which countries do most of Netflix's content come from currently?
4. What is the number of content items in each type of genre? Which genres are the most popular?
5. Find the top 10 actors/ actresses by the number of movies on Netflix that they were in.
</aside>

### Toggle to view full code

```sql
-- 1. What content types dominate Netflix's catalogue?

SELECT
	type,
	COUNT(*) AS count_by_type,
	ROUND(COUNT(*)*100/SUM(COUNT(*)) OVER(), 2) AS percent_of_total
FROM netflix
GROUP BY type;
```

```sql
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
```

```sql
-- 3. From which countries do most of Netflix's content come from currently?
-- to address combined values in the country column, we convert the string text in country column to array and unnesting the values, to effectively parse out the countries listed

SELECT 
	TRIM(UNNEST(STRING_TO_ARRAY(country, ','))) AS countries_new,
	COUNT(*) AS num_of_content
FROM netflix
GROUP BY countries_new
ORDER BY num_of_content DESC
LIMIT 5;
```

```sql
-- 4. What is the number of content items in each type of genre?
-- to address combined values in the listed_in column, we convert the string text in listed_in column to array, and unnesting the values, to effectively parse out the genres listed

SELECT 
	TRIM(UNNEST(STRING_TO_ARRAY(listed_in, ','))) AS genre_type,
	COUNT(*)
FROM netflix
GROUP BY genre_type
ORDER BY COUNT(*) DESC;
```

```sql
-- 5. Find the top 10 actors/ actresses by the number of movies on Netflix that they were in.

SELECT
	TRIM(UNNEST(STRING_TO_ARRAY(casts, ','))) AS actoractress,
	COUNT(*)
FROM netflix
WHERE type = 'Movie'
GROUP BY actoractress
ORDER BY COUNT(*) DESC
LIMIT 10;
```

---

## **Findings and Insights**

1. **Movies make up ~70% of Netflix’s catalogue, as compared to ~30% by TV shows.** 
    - This signifies a strategic skew towards long-form content over episodic content.
    - However, this affect user engagement for subscribers who prefer episodic, binge-worthy content.
    - According to a separate research, TV shows account for about 75% of viewing [(source)](https://www.bloomberg.com/news/newsletters/2022-03-13/these-are-netflix-s-most-popular-shows-according-to-netflix) on Netflix.
    - Netflix can consider rebalancing content investment by expanding its TV show catalogue to capitalise on the changing content consumption trend, which seems to favour short-form, episodic content.
    
2. **The most common rating is “TV-MA” for both Movies and TV shows, which denotes content for mature audiences (ages 17 and over)** 
    - This suggests that content on Netflix is skewed towards mature audiences, and could limit Netflix’s appeal towards the younger demographics, or family segments, especially families with young children.
    - With rising global demand in children’s media [(source)](https://www.parrotanalytics.com/insights/the-growth-and-changing-landscape-of-childrens-tv-shows-in-2023-in-the-uk/), Netflix can consider acquiring licensing rights for more family-friendly and PG-rated content to help diversify its offerings and enhance its competitiveness amongst customers seeking age-appropriate content.
    - Furthermore, Netflix’s on-demand model makes it well-positioned to meet the needs of families looking for flexible, accessible and convenient entertainment options for their children.
    
     
    
3. **Content from the US leads by a large margin, followed by content from India, and UK.** 
    - This concentration may limit Netflix’s resonance with diverse global audiences, especially in regions with a distinct cultural preferences or non-English speaking markets.
    - To improve internationalisation efforts and allow Netflix to reach a wider, global subscriber base, Netflix can consider increasing its investment in international content, especially content from Asia.
    - There has been increasing demand for asian-language TV content, led by growing demand for Chinese, Korean and Japanese language content [(source)](https://www.parrotanalytics.com/announcements/rise-studios-x-parrot-analytics-report-global-mena-demand-non-english-content/), especially within the MENA (Middle East & North America) region. Additionally, the ongoing Hallyu wave continues to fuel global interest in Korean content.
    - By diversifying its catalogue with more multilingual and international content, Netflix can strengthen its value proposition, improve subscriber acquisition in underpenetrated or growing international markets and better cater to growing demand in the MENA region.
    
4. **International Movies, Dramas and Comedies are the top genres available in Netflix’s content catalogue.**
    - The top 3 genres in terms of number of titles are “International Movies” (2752), “Dramas” (2427) and “Comedies”.
    - A high concentration of content items in these genres could indicate viewer preference, but could also suggest oversaturation of content in these genres, or redundancies.
    - Netflix could conduct further analysis on viewer engagement with these content genres to assess ROIs. Further research could also be done on genre trends within Netflix’s subscriber demographics to increase and differentiate offerings from competitors.
    
5. **The top actors include Anupam Kher, Shah Rukh Khan and Naseeruddin Shah, each starring in more than 30 movie titles available on the platform.** 
    - These popular actors likely draw significant viewership in the South Asian market, and the global Indian diaspora.
    - Popular actors and actresses can influence watch rates on Netflix where these actors are starred in. Given their regional influence and loyal fan base, Netflix can consider securing marketing collaborations or co-branded promotions with such popular actors and actresses.
    - This can help increase content and brand visibility, boost subscriber engagement with the brand, and improve regional performance in key growth, leveraging on the popularity of these actors.

---

## **Strategic Recommendations**

Based on the findings and insights and laid out above, Netflix can adopt a three-part strategy to strengthen content offerings and expand global and audience appeal:

1. **Content Rebalancing to capitalise on content viewing trends**
    
    While movies dominate the catalogue, episodic TV shows account for the majority of viewing time. Netflix should increase its investment in binge-worthy, episodic content to align with shifting user consumption patterns and improve overall viewer engagement.
    
2. **Diversify content catalogue acquisition to expand global and wider demographic appeal**
    
    Netflix’s content is skewed toward mature-rated and US-based titles, which may limit its appeal across families and non-English speaking markets. To widen its reach, Netflix should expand its catalogue of PG-rated and family-friendly content, and invest in acquisition of multilingual and international content.
    
3. **Secure celebrity and collaborations or co-branded marketing strategy to strengthen regional presence and brand visibility**
    
    Popular actors can drive significant content engagement, esepecially for titles carried by Netflix that they are starred in. Netflix can strengthen its brand affinity through strategic marketing collaborations, co-branded campaigns, or exclusive content partnerships with these celebrities to boost viewership and enhance subscriber loyalty. This can be further targeted through segmentation of celebrity popularity by region. 
    

---

## **Limitations**

This analysis provided insights to the composition of Netflix’s catalogue, in particular distribution by content type, content rating, country of production, and cast appearances. These findings can help guide future content acquisition and marketing strategies. 

However, the analysis is constrained by a few data limitations which should be acknowledged when interpreting the results. 

1. **Geographic limitations:** 
    - The `country` column reflects the country of production, and not the availability of content in specific regions. This restricts the ability to segment the data by content distribution region.
    - Additionally, the dataset was likely extracted using a user account based in India, which may have skewed the data towards content availability in the region. This dataset may not be representative of Netflix’s global catalogue due to regional licensing restrictions.
    
2. **Lack of user engagement metrics:**
    - The dataset does not include user engagement metrics (eg. watch time, user reviews/ ratings, bookmarks), limited the ability the assess content performance or user preferences.
    - With access to such metrics, there would be opportunity to further segment audience behaviour by region, age or other demographics to deliver more meaningful and targeted insights and recommendations.
    
3. **Missing values in key columns:**
    - Several fields such as the `country`, `director` and `casts` column contains a significant number of null values. However, these fields are highly specific to the context and traditional data impute methods may not be suitable, as opposed to, for example, time series values.
    - For example, it would not be accurate to impute the mode value for missing values in the director column, as each piece of content is uniquely tied to its actual director.
    - Rather than filling in inaccurate values, nulls were retained for such columns and accounted for in any aggregations or summaries, ensuring transparency in the limitations of the data.

---

## **Next Steps and Project Advancement**

1. **Combine this data set with subscriber demographic data (eg. user age, region) and subscriber engagement data (eg. watch time, user reviews/ ratings)** 
    - Allow for deeper understanding of audience behaviour and content performance across user segments and regions.
    
2. **Obtain a more complete and globally representative dataset of Netflix’s catalogue**
    - Ensures a more holistic understanding of Netflix’s offerings, without influence of regional content availability limitations or account-based content restrictions.
