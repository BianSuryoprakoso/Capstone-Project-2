-- SCHEMAS
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;
CREATE SCHEMA IF NOT EXISTS audit;

-- BRONZE LAYER (raw / staging)
CREATE TABLE IF NOT EXISTS bronze.raw_taxi_trips (
    vendor_id               INTEGER,
    tpep_pickup_datetime    TIMESTAMP,
    tpep_dropoff_datetime   TIMESTAMP,
    passenger_count         NUMERIC,
    trip_distance           NUMERIC,
    ratecode_id             NUMERIC,
    store_and_fwd_flag      TEXT,
    pulocation_id           INTEGER,
    dolocation_id           INTEGER,
    payment_type            NUMERIC,
    fare_amount             NUMERIC,
    extra                   NUMERIC,
    mta_tax                 NUMERIC,
    tip_amount              NUMERIC,
    tolls_amount            NUMERIC,
    improvement_surcharge   NUMERIC,
    total_amount            NUMERIC,
    congestion_surcharge    NUMERIC,
    airport_fee             NUMERIC,
    cbd_congestion_fee      NUMERIC,
    source_file             TEXT,
    loaded_at               TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bronze.raw_taxi_zones (
    locationid      INTEGER,
    borough         TEXT,
    zone            TEXT,
    service_zone    TEXT,
    source_file     TEXT,
    loaded_at       TIMESTAMP DEFAULT now()
);

-- SILVER LAYER (cleaned, standardized, validated)
CREATE TABLE IF NOT EXISTS silver.taxi_zones (
    location_id     INTEGER PRIMARY KEY,
    borough         TEXT NOT NULL,
    zone            TEXT NOT NULL,
    service_zone    TEXT
);

CREATE TABLE IF NOT EXISTS silver.taxi_trips_cleaned (
    trip_id                 BIGSERIAL PRIMARY KEY,
    vendor_id               INTEGER,
    pickup_datetime         TIMESTAMP NOT NULL,
    dropoff_datetime        TIMESTAMP NOT NULL,
    pickup_date             DATE NOT NULL,
    pickup_hour             INTEGER NOT NULL CHECK (pickup_hour BETWEEN 0 AND 23),
    pickup_day_name         TEXT NOT NULL,
    is_weekend              BOOLEAN NOT NULL,
    time_period             TEXT NOT NULL,
    trip_duration_minutes   NUMERIC NOT NULL CHECK (trip_duration_minutes >= 0),
    passenger_count         INTEGER,
    trip_distance           NUMERIC NOT NULL CHECK (trip_distance >= 0),
    pickup_location_id      INTEGER REFERENCES silver.taxi_zones(location_id),
    dropoff_location_id     INTEGER REFERENCES silver.taxi_zones(location_id),
    payment_type_label      TEXT,
    fare_amount              NUMERIC NOT NULL CHECK (fare_amount >= 0),
    tip_amount              NUMERIC NOT NULL CHECK (tip_amount >= 0),
    total_amount            NUMERIC NOT NULL CHECK (total_amount >= 0),
    created_at              TIMESTAMP DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trips_pickup_date ON silver.taxi_trips_cleaned (pickup_date);
CREATE INDEX IF NOT EXISTS idx_trips_pickup_zone ON silver.taxi_trips_cleaned (pickup_location_id);
CREATE INDEX IF NOT EXISTS idx_trips_dropoff_zone ON silver.taxi_trips_cleaned (dropoff_location_id);

CREATE TABLE IF NOT EXISTS silver.data_quality_issues (
    issue_id        BIGSERIAL PRIMARY KEY,
    error_type      TEXT NOT NULL,
    description     TEXT,
    pickup_datetime TIMESTAMP,
    dropoff_datetime TIMESTAMP,
    pulocation_id   INTEGER,
    dolocation_id   INTEGER,
    fare_amount     NUMERIC,
    total_amount    NUMERIC,
    raw_row_ref     TEXT,
    detected_at     TIMESTAMP DEFAULT now()
);

-- GOLD LAYER (mart)
CREATE TABLE IF NOT EXISTS gold.daily_trip_summary (
    pickup_date         DATE PRIMARY KEY,
    total_trips         BIGINT NOT NULL CHECK (total_trips >= 0),
    total_revenue       NUMERIC NOT NULL CHECK (total_revenue >= 0),
    avg_fare            NUMERIC,
    avg_distance        NUMERIC,
    avg_duration_minutes NUMERIC
);

-- AUDIT SCHEMA (pencatatan proses pipeline)
CREATE TABLE IF NOT EXISTS audit.load_audit (
    audit_id        BIGSERIAL PRIMARY KEY,
    layer           TEXT NOT NULL,        --'bronze', 'silver', 'gold'
    table_name      TEXT NOT NULL,
    process_name    TEXT NOT NULL,        --'BronzeLoader', 'SilverTransformer'
    status          TEXT NOT NULL,        --'SUCCESS', 'FAILED'
    row_count       BIGINT,
    started_at      TIMESTAMP NOT NULL,
    finished_at     TIMESTAMP,
    error_message   TEXT
);