-- CREATE SCHEMA analysis;

---- Colors Table
-- Checking the range of the fields so are able to allocate the right amount of storage space for each field
SELECT * FROM staging.colors;

SELECT 
	MIN(id),
	MAX(id),
	MAX(LENGTH(name)),
	MAX(LENGTH(rgb)),
	MAX(LENGTH(is_trans))
FROM staging.colors;

-- Checking if a version of the table already exists
DROP TABLE IF EXISTS analysis.colors CASCADE;

-- Creating the table and defining field types and storage sizes required
CREATE TABLE analysis.colors (
	id smallint,
	name varchar(50),
	rgb varchar(6),
	is_trans varchar(1)
);

-- Inserting the data from the staging table into the analysis table
INSERT INTO analysis.colors (
	SELECT * FROM staging.colors
);

---- Inventories Table
SELECT *
FROM staging.inventories;

SELECT 
	MIN(id),
	MAX(id),
	MIN(version),
	MAX(version),
	MAX(LENGTH(set_num))
FROM staging.inventories;

DROP TABLE IF EXISTS analysis.inventories CASCADE;

CREATE TABLE analysis.inventories (
	id smallint,
	version smallint,
	set_num varchar(16)
);

INSERT INTO analysis.inventories (
	SELECT * FROM staging.inventories
);

---- Inventory Parts Table
SELECT *
FROM staging.inventory_parts;

SELECT 
	MIN(inventory_id),
	MAX(inventory_id),
	MAX(LENGTH(part_num)),
	MIN(color_id),
	MAX(color_id),
	MIN(quantity),
	MAX(quantity),
	MAX(LENGTH(is_spare))
FROM staging.inventory_parts;

DROP TABLE IF EXISTS analysis.inventory_parts CASCADE;

CREATE TABLE analysis.inventory_parts (
	inventory_id smallint,
	part_num varchar(15),
	color_id smallint,
	quantity smallint,
	is_spare varchar(1)
);

INSERT INTO analysis.inventory_parts (
	SELECT * FROM staging.inventory_parts
);

---- Inventory Sets Table
SELECT *
FROM staging.inventory_sets;

SELECT 
	MIN(inventory_id),
	MAX(inventory_id),
	MAX(LENGTH(set_num)),
	MIN(quantity),
	MAX(quantity)
FROM staging.inventory_sets;

DROP TABLE IF EXISTS analysis.inventory_sets CASCADE;

CREATE TABLE analysis.inventory_sets (
	inventory_id smallint,
	set_num varchar(10),
	quantity smallint
);

INSERT INTO analysis.inventory_sets (
	SELECT * FROM staging.inventory_sets
);

---- Part Categories Table
SELECT *
FROM staging.part_categories;

SELECT 
	MIN(id),
	MAX(id),
	MAX(LENGTH(name))
FROM staging.part_categories;

DROP TABLE IF EXISTS analysis.part_categories CASCADE;

CREATE TABLE analysis.part_categories (
	id smallint,
	name varchar(45)
);

INSERT INTO analysis.part_categories (
	SELECT * FROM staging.part_categories
);

---- Parts Table
SELECT *
FROM staging.parts;

SELECT 
	MAX(LENGTH(part_num)),
	MAX(LENGTH(name)),
	MIN(part_cat_id),
	MAX(part_cat_id)
FROM staging.parts;

DROP TABLE IF EXISTS analysis.parts CASCADE;

CREATE TABLE analysis.parts (
	part_num varchar(15),
	name varchar(223),
	part_cat_id smallint
);

INSERT INTO analysis.parts (
	SELECT * FROM staging.parts
);

---- Sets Table
SELECT *
FROM staging.sets;

SELECT 
	MAX(LENGTH(set_num)),
	MAX(LENGTH(name)),
	MIN(year),
	MAX(year),
	MIN(theme_id),
	MAX(theme_id),
	MIN(num_parts),
	MAX(num_parts)
FROM staging.sets;

DROP TABLE IF EXISTS analysis.sets CASCADE;

CREATE TABLE analysis.sets (
	set_num varchar(16),
	name varchar(95),
	year smallint,
	theme_id smallint,
	num_parts smallint
);

INSERT INTO analysis.sets (
	SELECT * FROM staging.sets
);

---- Themes Table
SELECT *
FROM staging.themes;

SELECT 
	MIN(id),
	MAX(id),
	MAX(LENGTH(name)),
	MAX(LENGTH(parent_id))
FROM staging.themes;

DROP TABLE IF EXISTS analysis.themes CASCADE;

CREATE TABLE analysis.themes (
	id smallint,
	name varchar(32),
	parent_id varchar(3)
);

INSERT INTO analysis.themes (
	SELECT * FROM staging.themes
);

-- Adding primary keys to tables
ALTER TABLE analysis.colors ADD PRIMARY KEY (id);
ALTER TABLE analysis.inventories ADD PRIMARY KEY (id);
ALTER TABLE analysis.parts ADD PRIMARY KEY (part_num);
ALTER TABLE analysis.part_categories ADD PRIMARY KEY (id);
ALTER TABLE analysis.sets ADD PRIMARY KEY (set_num);
ALTER TABLE analysis.themes ADD PRIMARY KEY (id);

-- Investigating missing values in parts that exist in inventory parts
SELECT DISTINCT
	IP.part_num
FROM analysis.inventory_parts AS IP
LEFT JOIN analysis.parts AS P ON IP.part_num = P.part_num
WHERE P.part_num IS NULL;
-- 21 values in part_num from the Parts table do not existing in Inventory Parts - we will add these into the Inventory Parts table for now to enable the relationship

INSERT INTO analysis.parts (
	SELECT DISTINCT
		IP.part_num,
		NULL as name,
		CAST(NULL as smallint) as part_cat_id
		FROM analysis.inventory_parts as IP
	LEFT JOIN analysis.parts as P ON IP.part_num = P.part_num
	WHERE P.part_num IS NULL
);

-- Adding foreign keys to tables
ALTER TABLE analysis.parts ADD FOREIGN KEY (part_cat_id)
	REFERENCES analysis.part_categories(id);
ALTER TABLE analysis.sets ADD FOREIGN KEY (theme_id)
	REFERENCES analysis.themes(id);
ALTER TABLE analysis.inventory_sets ADD FOREIGN KEY (set_num)
	REFERENCES analysis.sets(set_num);
ALTER TABLE analysis.inventories ADD FOREIGN KEY (set_num)
	REFERENCES analysis.sets(set_num);
ALTER TABLE analysis.inventory_sets ADD FOREIGN KEY (inventory_id)
	REFERENCES analysis.inventories(id);
ALTER TABLE analysis.inventory_parts ADD FOREIGN KEY (inventory_id)
	REFERENCES analysis.inventories(id);
ALTER TABLE analysis.inventory_parts ADD FOREIGN KEY (part_num)
	REFERENCES analysis.parts(part_num);
ALTER TABLE analysis.inventory_parts ADD FOREIGN KEY (color_id)
	REFERENCES analysis.colors(id);


