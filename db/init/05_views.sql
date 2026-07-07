-- GOLD VIEWS: View siap pakai untuk analisis

-- 1. gold.vw_trip_enriched (trip + zone name + payment label)
CREATE OR REPLACE VIEW gold.vw_trip_enriched AS
SELECT
    t.trip_id,
    t.vendor_id,
    t.pickup_datetime,
    t.dropoff_datetime,
    t.pickup_date,
    t.pickup_hour,
    t.pickup_day_name,
    t.is_weekend,
    t.time_period,
    t.trip_duration_minutes,
    t.passenger_count,
    t.trip_distance,
    t.pickup_location_id,
    pz.borough AS pickup_borough,
    pz.zone AS pickup_zone,
    t.dropoff_location_id,
    dz.borough AS dropoff_borough,
    dz.zone AS dropoff_zone,
    t.payment_type_label,
    t.fare_amount,
    t.tip_amount,
    t.total_amount
FROM silver.taxi_trips_cleaned t
JOIN silver.taxi_zones pz ON t.pickup_location_id  = pz.location_id
JOIN silver.taxi_zones dz ON t.dropoff_location_id = dz.location_id;


-- 2. gold.vw_daily_trip_summary (ringkasan harian)
CREATE OR REPLACE VIEW gold.vw_daily_trip_summary AS
SELECT
    pickup_date,
    total_trips,
    total_revenue,
    avg_fare,
    avg_distance,
    avg_duration_minutes,

    --Running total revenue (akumulasi dari hari pertama)
    SUM(total_revenue) OVER (
        ORDER BY pickup_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_revenue,

    --Moving average trip count 7 hari
    ROUND(AVG(total_trips) OVER (
        ORDER BY pickup_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2
    ) AS moving_avg_7d_trips,

    --Revenue hari sebelumnya (untuk LAG comparison)
    LAG(total_revenue) OVER (
        ORDER BY pickup_date
    ) AS prev_day_revenue,

    --Selisih revenue dengan hari sebelumnya
    total_revenue - LAG(total_revenue) OVER (
        ORDER BY pickup_date
    ) AS revenue_diff_prev_day

FROM gold.daily_trip_summary;


-- 3. gold.vw_zone_performance (performa per zone + ranking)
CREATE OR REPLACE VIEW gold.vw_zone_performance AS
SELECT
    location_id,
    borough,
    zone,
    total_pickup_trips,
    total_dropoff_trips,
    total_revenue,
    avg_fare,
    avg_tip,

    -- Ranking zone berdasarkan total revenue (global)
    RANK() OVER (
        ORDER BY total_revenue DESC
    ) AS revenue_rank,

    -- Ranking zone per borough
    RANK() OVER (
        PARTITION BY borough
        ORDER BY total_revenue DESC
    ) AS revenue_rank_in_borough

FROM gold.zone_performance_summary;