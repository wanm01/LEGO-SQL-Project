# LEGO's Changing Colour Palette: A Time-Based Analysis
This project explores how LEGO’s colour palette has evolved by analysing the proportion of produced in each colour year by year.
<br>

### :bricks: About

This project examines how LEGO colours have changed over time by analysing the percentage of produced in each colour every year. Namely, this analysis shows how LEGO’s colour mix has evolved from a small group of core colours to a broader palette that includes more transparent, metallic, pearl, and specialised finishes. It also demonstrates that percentage prevalence provides a fairer view of colour trends as it adjusts for changes in the overall number of parts released each year.

Image of your dashboard:
<div style="overflow: hidden;margin: 0 10px 0 0">
<a href="https://public.tableau.com/app/profile/mandy.wan/viz/LEGOColoursover60Decades/LEGOColours">
<img src='https://raw.githubusercontent.com/wanm01/LEGO-SQL-Project/refs/heads/main/lego_colours_dashboard.png' width="100%">
</a>
</div>


### :oil_drum: Data Sources
- [LEGO Database](https://www.kaggle.com/datasets/rtatman/lego-database)
- [Schema Diagram](https://github.com/wanm01/LEGO-SQL-Project/blob/main/setup/lego_schema_erd_diagram.png)
- [Schema creation script](https://github.com/wanm01/LEGO-SQL-Project/blob/main/setup/lego_schema_setup.sql)


#### Import Script

This section of the script checks numeric ranges and maximum text lengths in the staging tables to inform the data types and field sizes used in the analysis schema. The example below profiles the colour data before creating its destination table.
```
SELECT
    MIN(id),
    MAX(id),
    MAX(LENGTH(name)),
    MAX(LENGTH(rgb)),
    MAX(LENGTH(is_trans))
FROM staging.colors;
```

This script recreates tables in the analysis schema with explicitly defined data types, then loads the corresponding data from staging. The same approach is used across the eight LEGO tables.
```
CREATE TABLE analysis.colors (
    id smallint,
    name varchar(50),
    rgb varchar(6),
    is_trans varchar(1)
);

INSERT INTO analysis.colors (
    SELECT *
    FROM staging.colors
);
```

Primary and foriegn keys are added where approriate.
```
-- Primary key:
ALTER TABLE analysis.colors ADD PRIMARY KEY (id);

-- Foreign key:
ALTER TABLE analysis.inventory_parts
ADD FOREIGN KEY (color_id)
REFERENCES analysis.colors(id);
```


### :toolbox: Data Reshape

The data is initially read and reshaped using an [SQL script](https://github.com/wanm01/LEGO-SQL-Project/blob/main/analysis/lego_colour_analysis.sql).

This script analyses how LEGO’s colour mix changes by the release year of the sets containing those parts. For every release year and colour, it calculates colour variety, colours by piece proportion, and colours by set proportion.

Of particular note are the sections that calculate the proportion of pieces of each colour released in each year (which is the metric used in the final visualisation) For example, this script calculates the number of pieces in each colour and the total number of pieces for each year. Using SUM(quantity) means the analysis counts individual pieces rather than simply counting inventory records.
```
year_colour_quantities AS (
    SELECT
        year,
        color_id,
        SUM(quantity) AS part_colour_quantity
    FROM colour_by_part_base
    GROUP BY
        year,
        color_id
    ORDER BY year
),

year_totals AS (
    SELECT
        year,
        SUM(quantity) AS part_total_quantity
    FROM colour_by_part_base
    GROUP BY year
    ORDER BY year
)
```

This section calculates each colour’s prevalence by dividing its annual piece quantity by the total piece quantity for the same year. Casting the numerator to numeric preserves decimal values, NULLIF protects against division by zero, and ROUND limits the result to four decimal places (which can then be formatted as a percentage in Tableau).
```
ROUND(
    YCQ.part_colour_quantity::numeric
    / NULLIF(YT.part_total_quantity, 0),
    4
) AS colour_piece_pct
```

The yearly totals are matched to each colour using the release year:
```
FROM year_colour_quantities AS YCQ
INNER JOIN year_totals AS YT
    ON YCQ.year = YT.year
INNER JOIN analysis.colors AS C
    ON YCQ.color_id = C.id
```

### :waffle: The Waffle Chart

The data is then transformed into a format suitable for creating waffle charts using an [SQL script](https://github.com/wanm01/LEGO-SQL-Project/blob/main/analysis/lego_colour_waffle_chart.sql).

Each year is represented by a brick containing 400 cells, with each cell representing 0.25% of that year’s total pieces. Colours are assigned cells in proportion to their annual piece quantities.

This section generates coordinates for the brick’s rectangular body and two studs. Together, they form 400 cells: 320 for the body and 80 for the studs. Each cell receives a fill-order number, moving from bottom-left to top-right.
```
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
```

The script calculates the ideal number of cells for each colour using its share of annual piece quantities.
```
s.part_colour_quantity::numeric
/ NULLIF(s.part_total_quantity, 0) * 400
AS ideal_cells
```

It then rounds down each allocation and distributes the remaining cells to colours with the largest fractional remainders. This ensures each year totals exactly 400 cells while keeping the allocations close to the original proportions.
```
r.base_cells
+ CASE
    WHEN r.remainder_rank <= d.cells_to_assign THEN 1
    ELSE 0
  END AS cell_count
```

This section uses cumulative totals to give each colour a start and end position within the 400-cell fill sequence. Colours are arranged alphabetically, so each colour occupies a consecutive band of cells.
```
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
```

The script expands each colour’s allocated range into individual cell records, then joins them to the brick coordinates. The final output includes the year, cell position, colour name, RGB code and underlying metrics.
```
expanded AS (
    SELECT
        b.year,
        b.colour_name,
        gs.fill_order
    FROM colour_bands AS b
    CROSS JOIN LATERAL generate_series(
        b.start_pos::bigint,
        b.end_pos::bigint
    ) AS gs(fill_order)
)
```

After initially plotting the above data in Tableau, I was not satisfied with its appearance. Therefore, I decided to create an additional script that would plot a border around the shape of the LEGO brick to better define its shape. 

This section retrieves the distinct non-null years from the yearly colour metrics view, ensuring the outlines cover the same years as the main data.
```
WITH source_years AS (
    SELECT DISTINCT year
    FROM analysis.lego_colour_yearly_metrics
    WHERE year IS NOT NULL
),
```

The outline_scaffold defines an ordered sequence of coordinates tracing the brick’s body and two studs. The half-unit coordinates place the outline around the outer edges of the waffle cells, rather than through their centres.
```
outline_scaffold AS (
    SELECT
        1 AS point_order,
        0.5 AS outline_x,
        0.5 AS outline_y,
        'bottom-left of body'

    UNION ALL SELECT 2, 32.5, 0.5, 'bottom-right of body'
    UNION ALL SELECT 3, 32.5, 10.5, 'top-right of body'
    UNION ALL SELECT 4, 29.5, 10.5, 'right edge of right stud'
    UNION ALL SELECT 5, 29.5, 14.5, 'top-right of right stud'
    -- Remaining points trace the rest of the brick.
```

The point_order field provides the drawing sequence for Tableau’s Path shelf. Repeating the starting coordinate at the end closes the outline. The script repeats that closing point twice; the second repetition is redundant and does not change the shape.
```
UNION ALL SELECT 12, 0.5, 10.5, 'top-left of body'
UNION ALL SELECT 13, 0.5, 0.5, 'close: repeat point 1'
UNION ALL SELECT 14, 0.5, 0.5, 'close: repeat point 1'
```

The CROSS JOIN pairs every year with every outline point, producing 14 rows per year. The output contains the year, an outline identifier, the drawing order and the X/Y coordinates, ready to form a separate outline layer alongside the coloured waffle cells.
```
SELECT
    y.year,
    'Brick' AS outline_id,
    s.point_order,
    s.outline_x,
    s.outline_y
FROM source_years AS y
CROSS JOIN outline_scaffold AS s
ORDER BY y.year, s.point_order;
```

