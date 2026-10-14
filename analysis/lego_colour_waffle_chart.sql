-- SCHEMA: analysis
SET search_path = 'analysis';

-- LEGO brick waffle chart = one brick per year, 400 cells per brick.
-- One cell = 0.25% of that year's pieces.

-- DROP VIEW analysis.lego_colour_waffle
 
CREATE VIEW analysis.lego_colour_waffle AS

WITH source AS (
    SELECT
        year,                      
        colour_name,      
		colour_id,
		colour_rgb,
        part_colour_quantity,     
        part_total_quantity,  
		colour_piece_pct,
		set_colour_quantity,
		set_total_quantity,
		colour_set_prevalence_pct AS set_colour_pct
    FROM analysis.lego_colour_yearly_metrics   
),

-- ---------------------------------------------------------------
-- 1. SCAFFOLD: the brick shape as 400 cells
--    Body: X 1-32, Y 1-10   (320 cells)
--    Studs: X 4-13 and 20-29, Y 11-14  (2 x 10 x 4 = 80 cells)
-- ---------------------------------------------------------------
body AS (
    SELECT g.x, g2.y
    FROM generate_series(1, 32) AS g(x)
    CROSS JOIN generate_series(1, 10) AS g2(y)
),
studs AS (
    SELECT g.x, g2.y
    FROM generate_series(4, 13) AS g(x)
    CROSS JOIN generate_series(11, 14) AS g2(y)
    UNION ALL
    SELECT g.x, g2.y
    FROM generate_series(20, 29) AS g(x)
    CROSS JOIN generate_series(11, 14) AS g2(y)
),
scaffold AS (
    SELECT x, y,
           ROW_NUMBER() OVER (ORDER BY y, x) AS fill_order   -- 1..400, bottom-left to top-right
    FROM (
        SELECT x, y FROM body
        UNION ALL
        SELECT x, y FROM studs
    ) AS cells
),

-- ---------------------------------------------------------------
-- 2. ALLOCATE: ideal cells from raw quantities then largest-remainder rounding so each year sums to  400
-- ---------------------------------------------------------------
ideal AS (
    SELECT
        s.year,
        s.colour_name,
        s.part_colour_quantity,
        s.part_total_quantity,
        s.colour_rgb,
        s.set_colour_pct,
        s.part_colour_quantity::numeric / NULLIF(s.part_total_quantity, 0) * 400
            AS ideal_cells
    FROM source AS s
),
floors AS (
    SELECT
        i.*,
        FLOOR(i.ideal_cells) AS base_cells,
        (i.ideal_cells - FLOOR(i.ideal_cells)) AS remainder
    FROM ideal AS i
),
ranked AS (
    SELECT
        f.*,
        ROW_NUMBER() OVER (
            PARTITION BY f.year
            ORDER BY f.remainder DESC, f.part_colour_quantity DESC, f.colour_name
        ) AS remainder_rank
    FROM floors AS f
),
year_deficit AS (
    SELECT year, 400 - SUM(base_cells) AS cells_to_assign
    FROM floors
    GROUP BY year
),
allocations AS (
    SELECT
        r.year,
        r.colour_name,
        r.colour_rgb,
        r.set_colour_pct,
        r.part_colour_quantity,
        r.part_total_quantity,
        r.base_cells
            + CASE WHEN r.remainder_rank <= d.cells_to_assign THEN 1 ELSE 0 END
            AS cell_count
    FROM ranked AS r
    INNER JOIN year_deficit AS d USING (year)
),

-- ---------------------------------------------------------------
-- 3. CELL RANGES: each colour gets a band of fill-order positions within the year in alphabetical colour order
-- ---------------------------------------------------------------
colour_bands AS (
    SELECT
        a.year,
        a.colour_name,
        a.colour_rgb,
        a.set_colour_pct,
        a.part_colour_quantity,
        a.part_total_quantity,
        a.cell_count,
        COALESCE(
            SUM(a.cell_count) OVER (
                PARTITION BY a.year
                ORDER BY a.colour_name
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ),
            0
        ) + 1 AS start_pos,
        SUM(a.cell_count) OVER (
            PARTITION BY a.year
            ORDER BY a.colour_name
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS end_pos
    FROM allocations AS a
),

-- ---------------------------------------------------------------
-- 4. EXPAND: one row per year x cell, joined to the scaffold
-- ---------------------------------------------------------------
expanded AS (
    SELECT
        b.year,
        b.colour_name,
        gs.fill_order
    FROM colour_bands AS b
    CROSS JOIN LATERAL generate_series(
        b.start_pos::bigint, b.end_pos::bigint
    ) AS gs(fill_order)
)

SELECT
    DENSE_RANK() OVER (ORDER BY e.year) - 1 AS year_index,
    e.year,
    sc.x,
    sc.y,
    sc.fill_order AS cell_id,
    e.colour_name,
    b.colour_rgb,
    b.part_colour_quantity,
    b.part_total_quantity,
    b.part_colour_quantity::numeric
        / NULLIF(b.part_total_quantity, 0) AS part_colour_share,
    b.set_colour_pct
FROM expanded AS e
INNER JOIN scaffold AS sc ON e.fill_order = sc.fill_order
INNER JOIN colour_bands AS b
    ON e.year = b.year AND e.fill_order BETWEEN b.start_pos AND b.end_pos
ORDER BY e.year, sc.y, sc.x;