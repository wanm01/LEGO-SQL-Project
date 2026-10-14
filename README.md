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

The data is initially read and reshaped using an [SQL script](https://github.com/wanm01/LEGO-SQL-Project/blob/main/analysis/lego_colour_analysis.sql), 

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

TBC
