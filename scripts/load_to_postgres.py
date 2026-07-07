import pandas as pd
from datetime import datetime
from psycopg2.extras import execute_values
from database import DatabaseConnection


class LoadAuditRepository:
    """
    catat proses load ke tabel audit.load_audit.
    """

    def __init__(self, db: DatabaseConnection):
        self.db = db

    def start(self, layer, table_name, process_name):
        conn = self.db.connect()
        cur = conn.cursor()

        cur.execute(
            """
            INSERT INTO audit.load_audit (layer, table_name, process_name, status, started_at)
            VALUES (%s, %s, %s, 'RUNNING', %s)
            RETURNING audit_id;
            """,
            (layer, table_name, process_name, datetime.now())
        )
        audit_id = cur.fetchone()[0]

        conn.commit()
        cur.close()
        conn.close()
        return audit_id

    def finish_success(self, audit_id, row_count):
        conn = self.db.connect()
        cur = conn.cursor()

        cur.execute(
            """
            UPDATE audit.load_audit
            SET status = 'SUCCESS', row_count = %s, finished_at = %s
            WHERE audit_id = %s;
            """,
            (row_count, datetime.now(), audit_id)
        )

        conn.commit()
        cur.close()
        conn.close()

    def finish_failed(self, audit_id, error_message):
        conn = self.db.connect()
        cur = conn.cursor()

        cur.execute(
            """
            UPDATE audit.load_audit
            SET status = 'FAILED', error_message = %s, finished_at = %s
            WHERE audit_id = %s;
            """,
            (error_message, datetime.now(), audit_id)
        )

        conn.commit()
        cur.close()
        conn.close()


class BronzeLoader:
    """
    baca file CSV/Parquet, lalu masukkan ke tabel bronze.
    """

    def __init__(self, db: DatabaseConnection, audit_repo: LoadAuditRepository):
        self.db = db
        self.audit_repo = audit_repo

    def load_taxi_zones(self, file_path):
        audit_id = self.audit_repo.start("bronze", "bronze.raw_taxi_zones", "BronzeLoader")

        try:
            df = pd.read_csv(file_path)
            df.columns = [c.lower() for c in df.columns]
            df["source_file"] = file_path.split("/")[-1]

            df = df[["locationid", "borough", "zone", "service_zone", "source_file"]]
            df = df.where(pd.notnull(df), None)  # NaN -> None (jadi NULL di database)

            records = list(df.itertuples(index=False, name=None))

            conn = self.db.connect()
            cur = conn.cursor()

            cur.execute("TRUNCATE TABLE bronze.raw_taxi_zones;")

            # execute_values mengirim SEMUA baris dalam satu kali perintah ke database
            execute_values(
                cur,
                """
                INSERT INTO bronze.raw_taxi_zones
                    (locationid, borough, zone, service_zone, source_file)
                VALUES %s;
                """,
                records
            )

            conn.commit()
            cur.close()
            conn.close()

            row_count = len(df)
            self.audit_repo.finish_success(audit_id, row_count)
            print(f"[BronzeLoader] raw_taxi_zones loaded: {row_count} rows")
            return row_count

        except Exception as e:
            self.audit_repo.finish_failed(audit_id, str(e))
            print(f"[BronzeLoader] FAILED loading taxi_zones: {e}")
            raise

    def load_taxi_trips(self, file_path):
        audit_id = self.audit_repo.start("bronze", "bronze.raw_taxi_trips", "BronzeLoader")

        try:
            df = pd.read_parquet(file_path)
            df.columns = [c.lower() for c in df.columns]
            df["source_file"] = file_path.split("/")[-1]
            columns = [
                "vendorid", "tpep_pickup_datetime", "tpep_dropoff_datetime",
                "passenger_count", "trip_distance", "ratecodeid",
                "store_and_fwd_flag", "pulocationid", "dolocationid",
                "payment_type", "fare_amount", "extra", "mta_tax",
                "tip_amount", "tolls_amount", "improvement_surcharge",
                "total_amount", "congestion_surcharge", "airport_fee",
                "cbd_congestion_fee", "source_file",
            ]
            df = df[columns]
            df = df.where(pd.notnull(df), None)  # NaN -> None

            # Ubah ke list of tuple sekali jalan
            records = list(df.itertuples(index=False, name=None))

            conn = self.db.connect()
            cur = conn.cursor()

            cur.execute("TRUNCATE TABLE bronze.raw_taxi_trips;")

            execute_values(
                cur,
                """
                INSERT INTO bronze.raw_taxi_trips (
                    vendor_id, tpep_pickup_datetime, tpep_dropoff_datetime,
                    passenger_count, trip_distance, ratecode_id,
                    store_and_fwd_flag, pulocation_id, dolocation_id,
                    payment_type, fare_amount, extra, mta_tax,
                    tip_amount, tolls_amount, improvement_surcharge,
                    total_amount, congestion_surcharge, airport_fee,
                    cbd_congestion_fee, source_file
                ) VALUES %s;
                """,
                records,
                page_size=10000 #data dikirim ke database per 10.000 baris sekaligus
            )

            conn.commit()
            cur.close()
            conn.close()

            row_count = len(df)
            self.audit_repo.finish_success(audit_id, row_count)
            print(f"[BronzeLoader] raw_taxi_trips loaded: {row_count} rows")
            return row_count

        except Exception as e:
            self.audit_repo.finish_failed(audit_id, str(e))
            print(f"[BronzeLoader] FAILED loading taxi_trips: {e}")
            raise