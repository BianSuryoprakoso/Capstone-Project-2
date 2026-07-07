# Entity Relationship Diagram (ERD)

## Diagram Relasi

```mermaid
erDiagram
  bronze_raw_taxi_zones {
    INTEGER locationid
    TEXT borough
    TEXT zone
    TEXT service_zone
    TEXT source_file
    TIMESTAMP loaded_at
  }

  bronze_raw_taxi_trips {
    INTEGER vendor_id
    TIMESTAMP tpep_pickup_datetime
    TIMESTAMP tpep_dropoff_datetime
    NUMERIC passenger_count
    NUMERIC trip_distance
    NUMERIC payment_type
    NUMERIC fare_amount
    NUMERIC tip_amount
    NUMERIC total_amount
    TEXT source_file
    TIMESTAMP loaded_at
  }

  silver_taxi_zones {
    INTEGER location_id PK
    TEXT borough
    TEXT zone
    TEXT service_zone
  }

  silver_taxi_trips_cleaned {
    BIGSERIAL trip_id PK
    INTEGER vendor_id
    TIMESTAMP pickup_datetime
    TIMESTAMP dropoff_datetime
    DATE pickup_date
    INTEGER pickup_hour
    TEXT pickup_day_name
    BOOLEAN is_weekend
    TEXT time_period
    NUMERIC trip_duration_minutes
    INTEGER passenger_count
    NUMERIC trip_distance
    INTEGER pickup_location_id FK
    INTEGER dropoff_location_id FK
    TEXT payment_type_label
    NUMERIC fare_amount
    NUMERIC tip_amount
    NUMERIC total_amount
  }

  silver_data_quality_issues {
    BIGSERIAL issue_id PK
    TEXT error_type
    TEXT description
    TIMESTAMP pickup_datetime
    TIMESTAMP dropoff_datetime
    INTEGER pulocation_id
    NUMERIC fare_amount
    TIMESTAMP detected_at
  }

  gold_daily_trip_summary {
    DATE pickup_date PK
    BIGINT total_trips
    NUMERIC total_revenue
    NUMERIC avg_fare
    NUMERIC avg_distance
    NUMERIC avg_duration_minutes
  }

  gold_zone_performance_summary {
    INTEGER location_id PK
    TEXT borough
    TEXT zone
    BIGINT total_pickup_trips
    BIGINT total_dropoff_trips
    NUMERIC total_revenue
    NUMERIC avg_fare
    NUMERIC avg_tip
  }

  gold_payment_behavior_summary {
    TEXT payment_type_label PK
    BIGINT total_trips
    NUMERIC total_revenue
    NUMERIC avg_fare
    NUMERIC avg_tip
    NUMERIC pct_of_total_trips
  }

  audit_load_audit {
    BIGSERIAL audit_id PK
    TEXT layer
    TEXT table_name
    TEXT process_name
    TEXT status
    BIGINT row_count
    TIMESTAMP started_at
    TIMESTAMP finished_at
    TEXT error_message
  }

  bronze_raw_taxi_zones ||--o{ bronze_raw_taxi_trips : "lokasi ref"
  bronze_raw_taxi_zones ||--|| silver_taxi_zones : "transform"
  bronze_raw_taxi_trips ||--o{ silver_taxi_trips_cleaned : "transform"
  bronze_raw_taxi_trips ||--o{ silver_data_quality_issues : "quality check"
  silver_taxi_zones ||--o{ silver_taxi_trips_cleaned : "pickup FK"
  silver_taxi_zones ||--o{ silver_taxi_trips_cleaned : "dropoff FK"
  silver_taxi_trips_cleaned ||--|| gold_daily_trip_summary : "aggregate"
  silver_taxi_trips_cleaned ||--|| gold_zone_performance_summary : "aggregate"
  silver_taxi_trips_cleaned ||--|| gold_payment_behavior_summary : "aggregate"
```

---

## Penjelasan Relasi Antar Tabel

### Bronze Layer
| Tabel | Deskripsi |
|-------|-----------|
| `bronze.raw_taxi_trips` | Data perjalanan taxi raw langsung dari file Parquet |
| `bronze.raw_taxi_zones` | Data lookup zone taxi raw dari file CSV |

### Silver Layer
| Tabel | Deskripsi |
|-------|-----------|
| `silver.taxi_zones` | Zone lookup yang sudah dibersihkan dari bronze |
| `silver.taxi_trips_cleaned` | Trip data valid dengan kolom turunan dan FK ke taxi_zones |
| `silver.data_quality_issues` | Record tidak valid yang difilter dari bronze |

### Gold Layer
| Tabel | Deskripsi |
|-------|-----------|
| `gold.daily_trip_summary` | Agregasi harian: total trip, revenue, avg fare |
| `gold.hourly_demand_summary` | Agregasi per jam: demand dan revenue |
| `gold.zone_performance_summary` | Performa per zone: pickup, dropoff, revenue |
| `gold.payment_behavior_summary` | Ringkasan per payment type |
| `gold.route_performance_summary` | TOP 1000 rute pickup-dropoff terpopuler |

### Audit
| Tabel | Deskripsi |
|-------|-----------|
| `audit.load_audit` | Catatan setiap proses load/transform pipeline |

---

## Constraint Detail

| Tabel | Constraint | Kolom | Keterangan |
|-------|-----------|-------|-----------|
| `silver.taxi_zones` | PRIMARY KEY | `location_id` | ID unik per zone |
| `silver.taxi_trips_cleaned` | PRIMARY KEY | `trip_id` | Auto-increment |
| `silver.taxi_trips_cleaned` | FOREIGN KEY | `pickup_location_id` | Referensi ke `silver.taxi_zones` |
| `silver.taxi_trips_cleaned` | FOREIGN KEY | `dropoff_location_id` | Referensi ke `silver.taxi_zones` |
| `silver.taxi_trips_cleaned` | NOT NULL | `pickup_datetime`, `dropoff_datetime`, `pickup_date` | Wajib ada |
| `silver.taxi_trips_cleaned` | CHECK | `trip_distance >= 0` | Tidak boleh negatif |
| `silver.taxi_trips_cleaned` | CHECK | `fare_amount >= 0` | Tidak boleh negatif |
| `silver.taxi_trips_cleaned` | CHECK | `tip_amount >= 0` | Tidak boleh negatif |
| `silver.taxi_trips_cleaned` | CHECK | `total_amount >= 0` | Tidak boleh negatif |
| `silver.taxi_trips_cleaned` | CHECK | `pickup_hour BETWEEN 0 AND 23` | Jam valid |
| `gold.daily_trip_summary` | PRIMARY KEY | `pickup_date` | Satu baris per hari |
| `audit.load_audit` | PRIMARY KEY | `audit_id` | Auto-increment |
```
