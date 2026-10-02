-- 1. Classify e-bike rides by station coverage
SELECT
    CASE
        WHEN start_station_id IS NOT NULL
             AND end_station_id IS NOT NULL
            THEN 'station_to_station'

        WHEN start_station_id IS NULL
             AND end_station_id IS NOT NULL
            THEN 'missing_start_only'

        WHEN start_station_id IS NOT NULL
             AND end_station_id IS NULL
            THEN 'missing_end_only'

        ELSE 'missing_both'
    END AS station_status,

    COUNT(*) AS rides

FROM trips_raw

WHERE rideable_type = 'electric_bike'

GROUP BY station_status

ORDER BY rides DESC;

-- 2. Compare station-to-station coverage by bike type
SELECT
    rideable_type,
    COUNT(*) AS total_rides,

    SUM(
        CASE
            WHEN start_station_id IS NOT NULL
             AND end_station_id IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS station_to_station_rides

FROM trips_raw

GROUP BY rideable_type;



-- 3. Compare coverage between member and casual riders
SELECT
    member_casual,
    COUNT(*) AS total_ebike_rides,

    SUM(
        CASE
            WHEN start_station_id IS NOT NULL
             AND end_station_id IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS station_to_station_rides,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN start_station_id IS NOT NULL
                 AND end_station_id IS NOT NULL
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS station_coverage_pct

FROM trips_raw

WHERE rideable_type = 'electric_bike'

GROUP BY member_casual;


-- 4. Compare coverage between weekdays and weekends
SELECT
    EXTRACT(HOUR FROM started_at) AS start_hour,
    COUNT(*) AS total_ebike_rides,

    SUM(
        CASE
            WHEN start_station_id IS NOT NULL
             AND end_station_id IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS station_to_station_rides,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN start_station_id IS NOT NULL
                 AND end_station_id IS NOT NULL
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        1
    ) AS station_coverage_pct

FROM trips_raw

WHERE rideable_type = 'electric_bike'

GROUP BY start_hour

ORDER BY start_hour;
