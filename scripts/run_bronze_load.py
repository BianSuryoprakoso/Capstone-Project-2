from database import DatabaseConnection
from load_to_postgres import BronzeLoader, LoadAuditRepository

#entry point
if __name__ == "__main__":
    db = DatabaseConnection()
    audit_repo = LoadAuditRepository(db)
    loader = BronzeLoader(db, audit_repo)

    #Load zone lookup dulu
    loader.load_taxi_zones("../data/raw/taxi_zone_lookup.csv")

    #load trip data
    loader.load_taxi_trips("../data/raw/yellow_tripdata_2026-01.parquet")

    print("Bronze load selesai.")