-- Identify stations with morning net inflow and evening net outflow
-- and compare both absolute reversal magnitude and relative imbalance.

WITH departures AS (
    SELECT
        start_station_id AS station_id,
        MAX(start_station_name) AS station_name,

        CASE
            WHEN EXTRACT(HOUR FROM started_at) BETWEEN 6 AND 9
                THEN 'morning_peak'
            WHEN EXTRACT(HOUR FROM started_at) BETWEEN 16 AND 19
                THEN 'evening_peak'
        END AS time_period,

        COUNT(*) AS departures

    FROM trips_raw

    WHERE start_station_id IS NOT NULL
      AND (
            EXTRACT(HOUR FROM started_at) BETWEEN 6 AND 9
            OR EXTRACT(HOUR FROM started_at) BETWEEN 16 AND 19
          )

    GROUP BY start_station_id, time_period
),

arrivals AS (
    SELECT
        end_station_id AS station_id,
        MAX(end_station_name) AS station_name,

        CASE
            WHEN EXTRACT(HOUR FROM ended_at) BETWEEN 6 AND 9
                THEN 'morning_peak'
            WHEN EXTRACT(HOUR FROM ended_at) BETWEEN 16 AND 19
                THEN 'evening_peak'
        END AS time_period,

        COUNT(*) AS arrivals

    FROM trips_raw

    WHERE end_station_id IS NOT NULL
      AND (
            EXTRACT(HOUR FROM ended_at) BETWEEN 6 AND 9
            OR EXTRACT(HOUR FROM ended_at) BETWEEN 16 AND 19
          )

    GROUP BY end_station_id, time_period
),

station_flows AS (
    SELECT
        COALESCE(d.station_id, a.station_id) AS station_id,
        COALESCE(d.station_name, a.station_name) AS station_name,
        COALESCE(d.time_period, a.time_period) AS time_period,

        COALESCE(d.departures, 0) AS departures,
        COALESCE(a.arrivals, 0) AS arrivals,

        COALESCE(a.arrivals, 0)
            - COALESCE(d.departures, 0) AS net_flow,

        COALESCE(a.arrivals, 0)
            + COALESCE(d.departures, 0) AS total_flow

    FROM departures d

    FULL OUTER JOIN arrivals a
        ON d.station_id = a.station_id
        AND d.time_period = a.time_period
),

station_summary AS (
    SELECT
        station_id,
        MAX(station_name) AS station_name,

        MAX(
            CASE
                WHEN time_period = 'morning_peak'
                THEN net_flow
            END
        ) AS morning_net_flow,

        MAX(
            CASE
                WHEN time_period = 'evening_peak'
                THEN net_flow
            END
        ) AS evening_net_flow,

        MAX(
            CASE
                WHEN time_period = 'morning_peak'
                THEN total_flow
            END
        ) AS morning_total_flow,

        MAX(
            CASE
                WHEN time_period = 'evening_peak'
                THEN total_flow
            END
        ) AS evening_total_flow

    FROM station_flows

    GROUP BY station_id
)

SELECT
    station_id,
    station_name,

    morning_net_flow,
    evening_net_flow,

    morning_net_flow - evening_net_flow
        AS reversal_magnitude,

    ROUND(
        100.0 * ABS(morning_net_flow)
        / NULLIF(morning_total_flow, 0),
        1
    ) AS morning_imbalance_pct,

    ROUND(
        100.0 * ABS(evening_net_flow)
        / NULLIF(evening_total_flow, 0),
        1
    ) AS evening_imbalance_pct

FROM station_summary

WHERE morning_net_flow > 0
  AND evening_net_flow < 0

ORDER BY reversal_magnitude DESC

LIMIT 15;