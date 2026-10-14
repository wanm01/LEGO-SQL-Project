-- SCHEMA: analysis
SET search_path = 'analysis';

-- The key question this analysis will aim to answer is "How has LEGO's colour fingerprint changed over time?"
-- This will look at the following measures:
---- How many colours released across years
---- How many pieces with the same colours across years
---- How many sets use each colour across years

-- DROP VIEW analysis.lego_colour_yearly_metrics
 
CREATE VIEW analysis.lego_colour_yearly_metrics AS

-- Compiling info about colours per year into a single CTE
WITH colour_by_part_base AS (
    SELECT
        S.year,
        S.set_num,
        IP.part_num,
        IP.color_id,
		C.name,
        IP.quantity
    FROM analysis.inventory_parts AS IP
    INNER JOIN Analysis.inventories AS I
        ON IP.inventory_id = I.id
    INNER JOIN analysis.sets AS S
        ON I.set_num = S.set_num
	INNER JOIN analysis.colors AS C
    ON IP.color_id = C.id
    WHERE S.year IS NOT NULL
      AND IP.quantity > 0
      AND IP.is_spare = 'f'
),

-- Analysing the annual variety of colours by year (i.e. the number of distinct colours in at least one non-spare part across sets in each year)
year_colour_count AS (
	SELECT 
		year,
		COUNT(DISTINCT color_id) AS colour_variety
	FROM colour_by_part_base
	GROUP BY year
	ORDER BY year
),

-- Calculating the total number of parts in each colour per year
year_colour_quantities AS (
	SELECT 
		year,
		color_id,
		SUM(quantity) AS part_colour_quantity
	FROM colour_by_part_base
	GROUP BY year,
		color_id
	ORDER BY year
),

-- Calculating the total number of parts per year
year_totals AS (
	SELECT
		year,
		SUM(quantity) AS part_total_quantity
	FROM colour_by_part_base
	GROUP BY year
	ORDER BY year
),

-- Analysing the % prevalence of each coloured part out of the total part for every year
year_colour_pct AS (
	SELECT
	    YCQ.year,
	    YCQ.color_id,
	    C.name,
	    C.rgb AS colour_rgb,
		C.is_trans,
	    YCQ.part_colour_quantity,
	    YT.part_total_quantity,
	    ROUND(
	        YCQ.part_colour_quantity::numeric
	        / NULLIF(YT.part_total_quantity, 0),
	        4
	    ) AS colour_piece_pct
	FROM year_colour_quantities AS YCQ
	INNER JOIN year_totals AS YT
	    ON YCQ.year = YT.year
	INNER JOIN analysis.colors AS C
	    ON YCQ.color_id = C.id
	ORDER BY
	    YCQ.year,
	    colour_piece_pct DESC
),

-- Calculating the total number of sets with at one least one piece for each colour per year
sets_per_colour AS (
    SELECT
        year,
        color_id,
        COUNT(DISTINCT set_num) AS set_colour_quantity
    FROM colour_by_part_base
    GROUP BY
        year,
        color_id
),

-- Calculating the total number of sets per year
sets_per_year AS (
    SELECT
        year,
        COUNT(DISTINCT set_num) AS set_total_quantity
    FROM colour_by_part_base
    GROUP BY year
),

-- Analysing the proportion of sets each year that contain at least one part in each colour
year_sets_by_colour AS (
	SELECT
	    SPC.year,
	    SPC.color_id,
	    C.name AS colour_name,
	    C.rgb AS colour_rgb,
	    SPC.set_colour_quantity,
	    SPY.set_total_quantity,
	    ROUND(
	        SPC.set_colour_quantity::numeric
	        / NULLIF(SPY.set_total_quantity, 0),
	        4
	    ) AS colour_set_prevalence_pct
	FROM sets_per_colour AS SPC
	INNER JOIN sets_per_year AS SPY
	    ON SPC.year = SPY.year
	INNER JOIN analysis.colors AS C
	    ON SPC.color_id = C.id
	ORDER BY
	    SPC.year,
	    colour_set_prevalence_pct DESC
)

-- Compiling the 3 colour analyses into a single view
SELECT 
	CC.year,
	CC.colour_variety,
	CP.color_id AS colour_id,
	colour_name,
	SC.colour_rgb,
	CP.is_trans,
	part_colour_quantity,
	part_total_quantity,
	colour_piece_pct,
	set_colour_quantity,
	set_total_quantity,
	colour_set_prevalence_pct
FROM year_colour_count AS CC
INNER JOIN year_colour_pct AS CP
	ON CC.year = CP.year
INNER JOIN year_sets_by_colour AS SC
	ON CP.year = SC.year
	AND CP.color_id = SC.color_id
;




