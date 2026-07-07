-- BASIC QUERY, FILTERING, DAN AGGREGATION

-- Q1: Berapa jumlah total trip valid pada Januari 2026?
SELECT COUNT(*) AS total_valid_trips
FROM silver.taxi_trips_cleaned;

-- Q2: Berapa total revenue, average revenue, average fare, dan average tip?
SELECT
    ROUND(SUM(total_amount), 2)  AS total_revenue,
    ROUND(AVG(total_amount), 2)  AS avg_revenue,
    ROUND(AVG(fare_amount), 2)   AS avg_fare,
    ROUND(AVG(tip_amount), 2)    AS avg_tip
FROM silver.taxi_trips_cleaned;

-- Q5: Payment type apa yang paling sering digunakan?
SELECT
    payment_type_label,
    total_trips,
    total_revenue,
    pct_of_total_trips
FROM gold.payment_behavior_summary
ORDER BY total_trips DESC;


-- JOIN DAN LOCATION ANALYSIS

-- Q6: Borough atau zone pickup mana yang memiliki jumlah trip tertinggi?
-- Per borough
SELECT
    pickup_borough,
    COUNT(*) AS total_trips
FROM gold.vw_trip_enriched
GROUP BY pickup_borough
ORDER BY total_trips DESC;

-- Per zone (top 10)
SELECT
    pickup_zone,
    pickup_borough,
    COUNT(*) AS total_trips
FROM gold.vw_trip_enriched
GROUP BY pickup_zone, pickup_borough
ORDER BY total_trips DESC
LIMIT 10;

-- Q7: Zone pickup mana yang menghasilkan total revenue tertinggi?
SELECT
    zone,
    borough,
    total_revenue,
    avg_fare,
    avg_tip,
    total_pickup_trips
FROM gold.zone_performance_summary
ORDER BY total_revenue DESC
LIMIT 10;

-- Q8: Rute pickup zone ke dropoff zone mana yang paling sering terjadi?
SELECT
    pickup_zone,
    dropoff_zone,
    pickup_borough,
    dropoff_borough,
    total_trips,
    total_revenue
FROM gold.route_performance_summary
ORDER BY total_trips DESC
LIMIT 10;


-- DATE, TIME, DAN DATA QUALITY

-- Q10: Tampilkan data quality issue terbanyak berdasarkan error_type
SELECT
    error_type,
    COUNT(*) AS total_issues
FROM silver.data_quality_issues
GROUP BY error_type
ORDER BY total_issues DESC;



-- CTE, SUBQUERY, DAN ADVANCED JOIN

-- Q13: Top 10 pickup zone berdasarkan revenue
WITH zone_revenue AS (
    SELECT
        pickup_location_id,
        ROUND(SUM(total_amount), 2) AS total_revenue,
        COUNT(*) AS total_trips,
        ROUND(AVG(tip_amount), 2) AS avg_tip
    FROM silver.taxi_trips_cleaned
    GROUP BY pickup_location_id
)
SELECT
    z.zone,
    z.borough,
    zr.total_revenue,
    zr.total_trips,
    zr.avg_tip
FROM zone_revenue zr
JOIN silver.taxi_zones z ON zr.pickup_location_id = z.location_id
ORDER BY zr.total_revenue DESC
LIMIT 10;

