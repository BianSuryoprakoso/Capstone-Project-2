-- =====================================================
-- WINDOW FUNCTION ANALYSIS Q18 - Q23
-- =====================================================

-- Q18: Ranking pickup zone berdasarkan total revenue
SELECT
    zone,
    borough,
    total_revenue,
    total_pickup_trips,
    RANK()       OVER (ORDER BY total_revenue DESC) AS revenue_rank,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS revenue_dense_rank
FROM gold.zone_performance_summary
ORDER BY revenue_rank
LIMIT 20;

-- Q19: Ranking pickup zone per borough
SELECT
    borough,
    zone,
    total_revenue,
    total_pickup_trips,
    RANK() OVER (
        PARTITION BY borough
        ORDER BY total_revenue DESC
    ) AS rank_in_borough
FROM gold.zone_performance_summary
ORDER BY borough, rank_in_borough
LIMIT 30;

