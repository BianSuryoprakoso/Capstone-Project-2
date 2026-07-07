## Deskripsi Project
Project ini membangun database analytics untuk data New York City Yellow Taxi bulan Januari 2026 menggunakan PostgreSQL dengan medallion architecture (Bronze → Silver → Gold). Data diambil dari hasil extract Capstone Project 1, kemudian diproses menggunakan SQL dan Python.

## Teknologi yang Digunakan
- PostgreSQL 16 (via Docker)
- Python 3 (psycopg2, pandas, pyarrow, python-dotenv)
- Docker & Docker Compose
- SQL (DDL, DML, CTE, Window Function, View)

### 1. Siapkan file raw data
Simpan raw data di folder `data/raw/`:
- `yellow_tripdata_2026-01.parquet` (NYC Yellow Taxi January 2026)
- `taxi_zone_lookup.csv` (Taxi Zone Lookup Table)

### 2. Buat file `.env` di root project
POSTGRES_USER=capstone_user
POSTGRES_PASSWORD=capstone_pass
POSTGRES_DB=nyc_taxi_db
POSTGRES_HOST=localhost
POSTGRES_PORT=5432

### 3. Jalankan pipeline (satu command)
```bash
bash scripts/run_database_pipeline.sh
```
Pipeline akan otomatis:
- Start Docker container PostgreSQL
- Membuat schema database
- Load data ke bronze
- Transformasi bronze ke silver
- Build gold mart & views
- Menjalankan business questions dan menyimpan hasilnya

### 4. Jalankan manual
```
# Start Docker
docker compose up -d

# Jalankan Pipeline Python
cd scripts
python main.py
```

### Struktur Folder
```
capstone_project_2/
├── data/
│   └── raw/                         
│       ├── yellow_tripdata_2026-01.parquet
│       └── taxi_zone_lookup.csv
├── db/
│   ├── init/
│   │   ├── 01_schema.sql         
│   │   ├── 03_silver_transform.sql 
│   │   ├── 04_gold_mart.sql 
│   │   └── 05_views.sql  
│   └── queries/
│       ├── 01_business_questions.sql
│       └── 02_window_analysis.sql 
├── docs/
│   ├── erd.md 
│   ├── insight_report.md
│   └── query_results/  
├── scripts/
│   ├── database.py 
│   ├── load_to_postgres.py 
│   ├── query_runner.py 
│   ├── main.py     
│   └── run_database_pipeline.sh     # Shell script automation
├── logs/               
├── .env  
├── .gitignore
├── docker-compose.yaml
├── requirements.txt
└── README.md
```