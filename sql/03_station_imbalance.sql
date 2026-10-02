-- Station-level departure, arrival, and directional imbalance analysis

-- 1. Top stations by trip departures
SELECT
    start_station_id,
    start_station_name,
    COUNT(*) AS departures
FROM trips_raw
WHERE start_station_id IS NOT NULL
GROUP BY start_station_id, start_station_name
ORDER BY departures DESC
LIMIT 10;


-- 2. Monthly station-level directional imbalance
-- Aggregate by station ID to avoid duplicated station-name variants
WITH departures AS (
    SELECT
        start_station_id AS station_id,
        MAX(start_station_name) AS station_name,
        COUNT(*) AS departures
    FROM trips_raw
    WHERE start_station_id IS NOT NULL
    GROUP BY start_station_id
),

arrivals AS (
    SELECT
        end_station_id AS station_id,
        MAX(end_station_name) AS station_name,
        COUNT(*) AS arrivals
    FROM trips_raw
    WHERE end_station_id IS NOT NULL
    GROUP BY end_station_id
)

SELECT
    COALESCE(d.station_id, a.station_id) AS station_id,
    COALESCE(d.station_name, a.station_name) AS station_name,
    COALESCE(d.departures, 0) AS departures,
    COALESCE(a.arrivals, 0) AS arrivals,
    COALESCE(a.arrivals, 0) - COALESCE(d.departures, 0) AS net_flow

FROM departures d

FULL OUTER JOIN arrivals a
    ON d.station_id = a.station_id

ORDER BY net_flow 

LIMIT 10;


-- 3. Station-level directional imbalance by time period
-- Departure periods use started_at; arrival periods use ended_at
WITH departures AS (
    SELECT
        start_station_id AS station_id,
        MAX(start_station_name) AS station_name,

        CASE
            WHEN EXTRACT(HOUR FROM started_at) BETWEEN 6 AND 9
                THEN 'morning_peak'
            WHEN EXTRACT(HOUR FROM started_at) BETWEEN 10 AND 15
                THEN 'midday'
            WHEN EXTRACT(HOUR FROM started_at) BETWEEN 16 AND 19
                THEN 'evening_peak'
            ELSE 'night'
        END AS time_period,

        COUNT(*) AS departures

    FROM trips_raw

    WHERE start_station_id IS NOT NULL

    GROUP BY start_station_id, time_period
),

arrivals AS (
    SELECT
        end_station_id AS station_id,
        MAX(end_station_name) AS station_name,

        CASE
            WHEN EXTRACT(HOUR FROM ended_at) BETWEEN 6 AND 9
                THEN 'morning_peak'
            WHEN EXTRACT(HOUR FROM ended_at) BETWEEN 10 AND 15
                THEN 'midday'
            WHEN EXTRACT(HOUR FROM ended_at) BETWEEN 16 AND 19
                THEN 'evening_peak'
            ELSE 'night'
        END AS time_period,

        COUNT(*) AS arrivals

    FROM trips_raw

    WHERE end_station_id IS NOT NULL

    GROUP BY end_station_id, time_period
)

SELECT
    COALESCE(d.station_id, a.station_id) AS station_id,
    COALESCE(d.station_name, a.station_name) AS station_name,
    COALESCE(d.time_period, a.time_period) AS time_period,

    COALESCE(d.departures, 0) AS departures,
    COALESCE(a.arrivals, 0) AS arrivals,

    COALESCE(a.arrivals, 0)
        - COALESCE(d.departures, 0) AS net_flow

FROM departures d

FULL OUTER JOIN arrivals a
    ON d.station_id = a.station_id
    AND d.time_period = a.time_period

ORDER BY net_flow DESC 

LIMIT 20;




-- 4. Top 5 stations with the strongest net outflow in each time period
WITH departures AS (
    SELECT
        start_station_id AS station_id,
        MAX(start_station_name) AS station_name,
        CASE
            WHEN EXTRACT(HOUR FROM started_at) BETWEEN 6 AND 9
                THEN 'morning_peak'
            WHEN EXTRACT(HOUR FROM started_at) BETWEEN 10 AND 15
                THEN 'midday'
            WHEN EXTRACT(HOUR FROM started_at) BETWEEN 16 AND 19
                THEN 'evening_peak'
            ELSE 'night'
        END AS time_period,
        COUNT(*) AS departures
    FROM trips_raw
    WHERE start_station_id IS NOT NULL
    GROUP BY start_station_id, time_period
),

arrivals AS (
    SELECT
        end_station_id AS station_id,
        MAX(end_station_name) AS station_name,
        CASE
            WHEN EXTRACT(HOUR FROM ended_at) BETWEEN 6 AND 9
                THEN 'morning_peak'
            WHEN EXTRACT(HOUR FROM ended_at) BETWEEN 10 AND 15
                THEN 'midday'
            WHEN EXTRACT(HOUR FROM ended_at) BETWEEN 16 AND 19
                THEN 'evening_peak'
            ELSE 'night'
        END AS time_period,
        COUNT(*) AS arrivals
    FROM trips_raw
    WHERE end_station_id IS NOT NULL
    GROUP BY end_station_id, time_period
),

station_flows AS (
    SELECT
        COALESCE(d.station_id, a.station_id) AS station_id,
        COALESCE(d.station_name, a.station_name) AS station_name,
        COALESCE(d.time_period, a.time_period) AS time_period,
        COALESCE(d.departures, 0) AS departures,
        COALESCE(a.arrivals, 0) AS arrivals,
        COALESCE(a.arrivals, 0) - COALESCE(d.departures, 0) AS net_flow
    FROM departures d
    FULL OUTER JOIN arrivals a
        ON d.station_id = a.station_id
        AND d.time_period = a.time_period
)

SELECT
    station_id,
    station_name,
    time_period,
    departures,
    arrivals,
    net_flow,

    ROW_NUMBER() OVER (
        PARTITION BY time_period
        ORDER BY net_flow
    ) AS outflow_rank

FROM station_flows

QUALIFY outflow_rank <= 5

ORDER BY time_period, outflow_rank;