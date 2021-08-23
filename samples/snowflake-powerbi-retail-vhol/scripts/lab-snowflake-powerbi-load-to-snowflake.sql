/*----------------------------------------------------------------------------
Snowflake and Power BI Hands-on Lab
Attaining Consumer Insights With Snowflake and Microsoft Power BI

Execute each section at a time following the steps in the lab guide

  Author(s):   Craig Collier, Regan Murphy
  Updated:  Original - 15-AUG-2021
  
----------------------------------------------------------------------------*/  

/* ---------------------------------------------------------------------------
   First we configure any required Warehouse(s), Role(s), User(s) as ACCOUNTADMIN
----------------------------------------------------------------------------*/

USE ROLE ACCOUNTADMIN;

-- Create Warehouse for ELT work
CREATE OR REPLACE WAREHOUSE ELT_WH
  WITH WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 120
  AUTO_RESUME = true
  INITIALLY_SUSPENDED = TRUE;

-- Create Warehouse for Power BI work
CREATE OR REPLACE WAREHOUSE POWERBI_WH
  WITH WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 120
  AUTO_RESUME = true
  INITIALLY_SUSPENDED = TRUE;

-- Create a Power BI Role

CREATE OR REPLACE ROLE POWERBI_ROLE COMMENT='Power BI Role';
GRANT ALL ON WAREHOUSE POWERBI_WH TO ROLE POWERBI_ROLE;
GRANT ROLE POWERBI_ROLE TO ROLE SYSADMIN;

-- Create a Power BI User
CREATE OR REPLACE USER POWERBI PASSWORD='PBISF123' 
    DEFAULT_ROLE=POWERBI_ROLE 
    DEFAULT_WAREHOUSE=POWERBI_WH
    DEFAULT_NAMESPACE=LAB_DW.PUBLIC
    COMMENT='Power BI User';

GRANT ROLE POWERBI_ROLE TO USER POWERBI;

  
-- Also grant all rights on the Warehouses to the SYSADMIN role
GRANT ALL ON WAREHOUSE ELT_WH TO ROLE SYSADMIN;
GRANT ALL ON WAREHOUSE POWERBI_WH TO ROLE SYSADMIN;

/* ---------------------------------------------------------------------------
   Next we create the Database as SYSADMIN and grant usage to POWERBI_ROLE
----------------------------------------------------------------------------*/

USE ROLE SYSADMIN;

-- Create the database
CREATE DATABASE IF NOT EXISTS LAB_DB;

GRANT USAGE ON DATABASE LAB_DB TO ROLE POWERBI_ROLE;

-- Ensure we are using the ELT warehouse so we don't affect Power BI users
USE WAREHOUSE ELT_WH;

-- Switch default context to the LAB_DB and PUBLIC schema
USE LAB_DB.PUBLIC;

-- Create the Category table
create or replace TABLE CATEGORY (
	CATEGORY_ID NUMBER(38,0),
	CATEGORY_NAME VARCHAR(50)
);

-- Create the Channels table
create or replace TABLE CHANNELS (
	CHANNEL_ID NUMBER(38,0),
	CHANNEL_NAME VARCHAR(50)
);

-- Create the Department table
create or replace TABLE DEPARTMENT (
	DEPARTMENT_ID NUMBER(38,0),
	DEPARTMENT_NAME VARCHAR(50)
);

-- Create the Items table
create or replace TABLE ITEMS (
	ITEM_ID NUMBER(38,0),
	ITEM_NAME VARCHAR(250),
	ITEM_PRICE FLOAT,
	DEPARTMENT_ID NUMBER(38,0),
	CATEGORY_ID NUMBER(38,0),
	TMP_ITEM_ID NUMBER(38,0)
);

-- Create the Sales Orders table
create or replace TABLE SALES_ORDERS (
	SALES_ORDER_ID NUMBER(38,0),
	CHANNEL_CODE NUMBER(38,0),
	CUSTOMER_ID NUMBER(38,0),
	PAYMENT_ID NUMBER(38,0),
	EMPLOYEE_ID NUMBER(38,0),
	LOCATION_ID NUMBER(38,0),
	SALES_DATE TIMESTAMP_NTZ(9),
	TMP_ORDER_ID FLOAT,
	TMP_ORDER_DOW NUMBER(38,0),
	TMP_USER_ID NUMBER(38,0)
);

-- Create the Sales Orders Items table
create or replace TABLE ITEMS_IN_SALES_ORDERS (
	SALES_ORDER_ID NUMBER(38,0),
	ITEM_ID NUMBER(38,0),
	ORDER_ID NUMBER(38,0),
	PROMOTION_ID NUMBER(38,0),
	QUANTITY FLOAT,
	REORDERED NUMBER(38,0),
	TMP_ORDER_ID FLOAT,
	TMP_PRODUCT_ID NUMBER(38,0)
);

-- Create the Locations table
-- This table will also contain Geospatial data in the GEO column
create or replace TABLE LOCATIONS (
	LOCATION_ID NUMBER(38,0),
	NAME VARCHAR(100),
	GEO2 VARCHAR(250),
	GEO GEOGRAPHY,
	LAT FLOAT,
	LONG FLOAT,
	COUNTRY VARCHAR(200),
	REGION VARCHAR(100),
	MUNICIPALITY VARCHAR(200),
	LONGITUDE FLOAT,
	LATITUDE FLOAT
);

-- Create the States table
create or replace TABLE STATES (
	STATE_CODE NUMBER(38,0),
	STATE_NAME VARCHAR(250),
	REGION VARCHAR(250),
	STATE_GEO VARCHAR(16777216)
);

/* ---------------------------------------------------------------------------
   GRANT READ ACCESS TO ALL TABLES IN LAB_DB TO POWERBI_ROLE
----------------------------------------------------------------------------*/
GRANT USAGE ON SCHEMA LAB_DB.PUBLIC TO ROLE POWERBI_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA LAB_DB.PUBLIC TO ROLE POWERBI_ROLE;

-- Create the External Data Stage pointing to the Azure Blob Container
-- REPLACE <YOURACCOUNT> with the Azure Blob Storage account name from Module 3.1
--              EXAMPLE Azure Blob Storage URL: url='azure://mystorageaccount.blob.core.windows.net/lab-data'
-- REPLACE <YOURSASTOKEN> with the SAS Token you generated in Module 3.3. 
--              EXAMPLE Azure SAS Token: azure_sas_token='?sp=racwdl&st=2021-08-12T23:07:31Z&se=2022-08-13T07:07:31Z&spr=https&sv=2020-08-04&sr=c&sig=MI%2BdVxquZR5helrns39j7%2BpfzxY%2FZt9YDSHOrjySug%3D
CREATE OR REPLACE STAGE LAB_DATA_STAGE 
    url='azure://YOURACCOUNT.blob.core.windows.net/lab-data'
    credentials=(azure_sas_token='YOURSASTOKEN');
    
-- Check that we can see the files in the External Data Stage using a LIST command    
LIST @LAB_DATA_STAGE;

/* ---------------------------------------------------------------------------
   Create a file format that understands our CSV specification and copy data
    from the Azure External Data Stage into the tables we created earlier
----------------------------------------------------------------------------*/

-- Create file format for the CSV files. 
-- These CSV files have no header, and the also require 'NULL' to be treated as null value
CREATE OR REPLACE FILE FORMAT CSVNOHEADER
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 0
    NULL_IF = ('NULL');

--  Load all the small tables and check samples
COPY INTO CATEGORY FROM @LAB_DATA_STAGE/category/ FILE_FORMAT = (FORMAT_NAME = CSVNOHEADER);
SELECT * FROM CATEGORY LIMIT 100;

COPY INTO CHANNELS FROM @LAB_DATA_STAGE/channels/ FILE_FORMAT = (FORMAT_NAME = CSVNOHEADER);
SELECT * FROM CHANNELS LIMIT 100;

COPY INTO DEPARTMENT from @LAB_DATA_STAGE/department/ FILE_FORMAT = (FORMAT_NAME = CSVNOHEADER);
SELECT * FROM DEPARTMENT LIMIT 100;

COPY INTO ITEMS from @LAB_DATA_STAGE/items/ FILE_FORMAT = (FORMAT_NAME = CSVNOHEADER);
SELECT * FROM ITEMS LIMIT 100;
SELECT COUNT(*) FROM ITEMS;

COPY INTO LOCATIONS from @LAB_DATA_STAGE/locations/ FILE_FORMAT = (FORMAT_NAME = CSVNOHEADER);
SELECT * FROM LOCATIONS LIMIT 100;
SELECT COUNT(*) FROM LOCATIONS;

COPY INTO STATES from @LAB_DATA_STAGE/states/ FILE_FORMAT = (FORMAT_NAME = CSVNOHEADER);
SELECT * FROM STATES LIMIT 100;

-- load the larger tables
-- check the files we have in the Sales Orders Items data
LIST @LAB_DATA_STAGE/items_in_sales_orders/;

-- there are 200 files, around 100MB each, which is around 20GB of compressed data
-- we will first load just one file and see how long it takes using the X-SMALL cluster
COPY INTO ITEMS_IN_SALES_ORDERS from @LAB_DATA_STAGE/items_in_sales_orders/items_in_sales_orders_0_0_0.csv.gz FILE_FORMAT = (FORMAT_NAME = CSVNOHEADER);



-- the above took ~20 seconds to load ~9 million rows.  we still have 199 more Sales Orders Items files to load, but that would  
-- take somewhere around 10-12 minutes if we kept the warehouse at X-SMALL.  Instead let's scale the warehouse to an XL

-- resize warehouse to X-LARGE
ALTER WAREHOUSE ELT_WH SET WAREHOUSE_SIZE = 'X-LARGE';

-- now copy the rest of the files in
COPY INTO ITEMS_IN_SALES_ORDERS from @LAB_DATA_STAGE/items_in_sales_orders/ FILE_FORMAT = (FORMAT_NAME = CSVNOHEADER);

-- that was much faster to load the remaning files! ~45 seconds instead of 10 minutes.
-- scaling up the warehouse like this is great for speeding up large ETL jobs

-- let's also copy the Sales Orders data in using the larger warehouse
COPY INTO SALES_ORDERS from @lab_data_stage/sales_orders/ FILE_FORMAT = (FORMAT_NAME = CSVNOHEADER);

-- we no longer need an XL warehouse, so let's stop paying for the extra 15 nodes by scaling back down to an XS
ALTER WAREHOUSE ELT_WH SET WAREHOUSE_SIZE = 'X-SMALL';

-- check the samples for the sales orders tables
SELECT * FROM SALES_ORDERS LIMIT 100;
SELECT COUNT(*) AS SALES_ORDERS_COUNT FROM SALES_ORDERS;

-- we have nearly 200 Million Sales Orders

SELECT * FROM ITEMS_IN_SALES_ORDERS LIMIT 100;
SELECT COUNT(*) AS ITEMS_IN_SALES_ORDERS_COUNT FROM ITEMS_IN_SALES_ORDERS;

-- we have nearly 1.8 Billion Sales Orders Items

/* ---------------------------------------------------------------------------
   Clean up and Reset dropping warehouses and objects
----------------------------------------------------------------------------*/

USE ROLE SYSADMIN;
DROP DATABASE IF EXISTS LAB_DB;
USE ROLE ACCOUNTADMIN;
DROP WAREHOUSE IF EXISTS ELT_WH;
DROP WAREHOUSE IF EXISTS POWERBI_WH;
