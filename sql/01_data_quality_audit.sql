SELECT
    rideable_type,
    COUNT(*) AS total_rides,

    SUM(
        CASE
            WHEN start_station_name IS NULL THEN 1
            ELSE 0
        END
    ) AS missing_start_station_name,

    SUM(
        CASE
            WHEN start_station_id IS NULL THEN 1
            ELSE 0
        END
    ) AS missing_start_station_id,

    SUM(
        CASE
            WHEN end_station_name IS NULL THEN 1
            ELSE 0
        END
    ) AS missing_end_station_name,

    SUM(
        CASE
            WHEN end_station_id IS NULL THEN 1
            ELSE 0
        END
    ) AS missing_end_station_id

FROM trips_raw
GROUP BY rideable_type;