import os
from database import DatabaseConnection
from load_to_postgres import BronzeLoader, LoadAuditRepository
from query_runner import QueryRunner

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.join(BASE_DIR, "..")

DB_INIT_DIR  = os.path.join(ROOT_DIR, "db", "init")
DATA_RAW_DIR = os.path.join(ROOT_DIR, "data", "raw")
OUTPUT_DIR   = os.path.join(ROOT_DIR, "docs", "query_results")


def run_sql_file(db: DatabaseConnection, sql_file_path: str, label: str):
    """
    Fungsi sederhana untuk membaca dan menjalankan file .sql ke PostgreSQL.
    Dipakai untuk schema, silver transform, gold mart, dan views.
    """
    print(f"\n[{label}] Menjalankan: {sql_file_path}")

    with open(sql_file_path, "r") as f:
        sql = f.read()

    conn = db.connect()
    cur = conn.cursor()

    try:
        cur.execute(sql)
        conn.commit()
        print(f"[{label}] Selesai.")
    except Exception as e:
        conn.rollback()
        print(f"[{label}] FAILED: {e}")
        raise
    finally:
        cur.close()
        conn.close()


def main():
    print("=" * 60)
    print("  NYC TAXI DATABASE PIPELINE - CAPSTONE PROJECT 2")
    print("=" * 60)

    db = DatabaseConnection()

    
    # STEP 1: Create Schema
    print("\n--- STEP 1: CREATE SCHEMA ---")
    run_sql_file(db, os.path.join(DB_INIT_DIR, "01_schema.sql"), "SchemaManager")

    # STEP 2: Load Bronze
    print("\n--- STEP 2: LOAD BRONZE ---")
    audit_repo = LoadAuditRepository(db)
    bronze_loader = BronzeLoader(db, audit_repo)
    bronze_loader.load_taxi_zones(
        os.path.join(DATA_RAW_DIR, "taxi_zone_lookup.csv")
    )
    bronze_loader.load_taxi_trips(
        os.path.join(DATA_RAW_DIR, "yellow_tripdata_2026-01.parquet")
    )

    # STEP 3: Transform Silver
    print("\n--- STEP 3: TRANSFORM BRONZE -> SILVER ---")
    run_sql_file(db, os.path.join(DB_INIT_DIR, "03_silver_transform.sql"), "SilverTransformer")

    # Tampilkan jumlah row hasil transformasi
    conn = db.connect()
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM silver.taxi_trips_cleaned;")
    count = cur.fetchone()[0]
    cur.close()
    conn.close()
    print(f"[SilverTransformer] silver.taxi_trips_cleaned: {count} rows")

    # STEP 4: Build Gold Mart
    print("\n--- STEP 4: BUILD GOLD MART ---")
    run_sql_file(db, os.path.join(DB_INIT_DIR, "04_gold_mart.sql"), "GoldMartBuilder")
    run_sql_file(db, os.path.join(DB_INIT_DIR, "05_views.sql"), "GoldMartBuilder")

    # STEP 5: Run Business Questions
    print("\n--- STEP 5: RUN BUSINESS QUESTIONS ---")
    runner = QueryRunner(db, output_dir=OUTPUT_DIR)

    # Q1: Total trip valid
    runner.run_query("Q1_total_trips", """
        SELECT COUNT(*) AS total_valid_trips
        FROM silver.taxi_trips_cleaned;
    """)

    # Q2: Total revenue, avg revenue, avg fare, avg tip
    runner.run_query("Q2_revenue_summary", """
        SELECT
            ROUND(SUM(total_amount), 2) AS total_revenue,
            ROUND(AVG(total_amount), 2) AS avg_revenue,
            ROUND(AVG(fare_amount), 2)  AS avg_fare,
            ROUND(AVG(tip_amount), 2)   AS avg_tip
        FROM silver.taxi_trips_cleaned;
    """)

    # Q5: Payment type terpopuler
    runner.run_query("Q5_payment_type", """
        SELECT payment_type_label, total_trips, total_revenue, pct_of_total_trips
        FROM gold.payment_behavior_summary
        ORDER BY total_trips DESC;
    """)

    # Q6: Borough & zone pickup tersibuk
    runner.run_query("Q6_top_borough", """
        SELECT pickup_borough, COUNT(*) AS total_trips
        FROM gold.vw_trip_enriched
        GROUP BY pickup_borough ORDER BY total_trips DESC;
    """)

    runner.run_query("Q6_top_zones", """
        SELECT pickup_zone, pickup_borough, COUNT(*) AS total_trips
        FROM gold.vw_trip_enriched
        GROUP BY pickup_zone, pickup_borough
        ORDER BY total_trips DESC LIMIT 10;
    """)

    # Q7: Zone dengan revenue tertinggi
    runner.run_query("Q7_top_revenue_zone", """
        SELECT zone, borough, total_revenue, avg_fare, total_pickup_trips
        FROM gold.zone_performance_summary
        ORDER BY total_revenue DESC LIMIT 10;
    """)

    # Q8: Rute paling sering
    runner.run_query("Q8_top_routes", """
        SELECT pickup_zone, dropoff_zone, pickup_borough, dropoff_borough,
               total_trips, total_revenue
        FROM gold.route_performance_summary
        ORDER BY total_trips DESC LIMIT 10;
    """)

    # Q10: Data quality issues
    runner.run_query("Q10_data_quality_issues", """
        SELECT error_type, COUNT(*) AS total_issues
        FROM silver.data_quality_issues
        GROUP BY error_type ORDER BY total_issues DESC;
    """)

    # Q13: Top 10 pickup zone by revenue (CTE)
    runner.run_query("Q13_top10_zone_revenue", """
        WITH zone_revenue AS (
            SELECT pickup_location_id,
                   ROUND(SUM(total_amount), 2) AS total_revenue,
                   COUNT(*) AS total_trips,
                   ROUND(AVG(tip_amount), 2) AS avg_tip
            FROM silver.taxi_trips_cleaned GROUP BY pickup_location_id
        )
        SELECT z.zone, z.borough, zr.total_revenue, zr.total_trips, zr.avg_tip
        FROM zone_revenue zr
        JOIN silver.taxi_zones z ON zr.pickup_location_id = z.location_id
        ORDER BY zr.total_revenue DESC LIMIT 10;
    """)

    # Q18: Ranking zone by revenue
    runner.run_query("Q18_zone_revenue_ranking", """
        SELECT zone, borough, total_revenue, total_pickup_trips,
               RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
        FROM gold.zone_performance_summary
        ORDER BY revenue_rank LIMIT 20;
    """)

    # Q19: Ranking zone per borough
    runner.run_query("Q19_zone_rank_per_borough", """
        SELECT borough, zone, total_revenue, total_pickup_trips,
               RANK() OVER (
                   PARTITION BY borough ORDER BY total_revenue DESC
               ) AS rank_in_borough
        FROM gold.zone_performance_summary
        ORDER BY borough, rank_in_borough LIMIT 30;
    """)

    print("\n" + "=" * 60)
    print("  PIPELINE SELESAI!")
    print(f"  Hasil query tersimpan di: docs/query_results/")
    print("=" * 60)


if __name__ == "__main__":
    main()