CREATE OR REPLACE TABLE trips_raw AS

SELECT *
FROM read_csv_auto('data/*.csv');