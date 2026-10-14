-- SCHEMA: analysis
SET search_path = 'analysis';

-- DROP VIEW analysis.lego_brick_outline

CREATE VIEW analysis.lego_brick_outline AS

-- ---------------------------------------------------------------
-- The silhouette: a 32x10 body with two 10x4 studs on top.
--   Body: X 0.5-32.5, Y 0.5-10.5   (outer edges of cells X 1-32, Y 1-10)
--   Left stud:  X 3.5-13.5, Y 10.5-14.5
--   Right stud: X 19.5-29.5, Y 10.5-14.5
-- One closed path with 14 corners, traced counter-clockwise from the bottom-left of the body, so the Path shelf connects them in order.
-- ---------------------------------------------------------------

WITH source_years AS (
    SELECT DISTINCT year
    FROM analysis.lego_colour_yearly_metrics  
    WHERE year IS NOT NULL
),

outline_scaffold AS (
    SELECT
        1  AS point_order, 0.5  AS outline_x, 0.5  AS outline_y, 'bottom-left of body'
        UNION ALL SELECT 2,  32.5,  0.5, 'bottom-right of body'
        UNION ALL SELECT 3,  32.5, 10.5, 'top-right of body'
        UNION ALL SELECT 4,  29.5, 10.5, 'right edge of right stud'
        UNION ALL SELECT 5,  29.5, 14.5, 'top-right of right stud'
        UNION ALL SELECT 6,  19.5, 14.5, 'top-left of right stud'
        UNION ALL SELECT 7,  19.5, 10.5, 'left edge of right stud'
        UNION ALL SELECT 8,  13.5, 10.5, 'right edge of left stud'
        UNION ALL SELECT 9,  13.5, 14.5, 'top-right of left stud'
        UNION ALL SELECT 10, 3.5,  14.5, 'top-left of left stud'
        UNION ALL SELECT 11, 3.5,  10.5, 'left edge of left stud'
        UNION ALL SELECT 12,  0.5, 10.5, 'top-left of body'
        UNION ALL SELECT 13,  0.5,  0.5, 'close: repeat point 1'
        UNION ALL SELECT 14,  0.5,  0.5, 'close: repeat point 1'
)

SELECT
    y.year,
    'Brick' AS outline_id,
    s.point_order,
    s.outline_x,
    s.outline_y
FROM source_years AS y
CROSS JOIN outline_scaffold AS s
ORDER BY y.year, s.point_order;