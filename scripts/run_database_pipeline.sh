#!/bin/bash

# Automation script: jalankan seluruh pipeline dengan satu commad


# Folder logs
LOG_DIR="logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/pipeline_$(date +%Y%m%d_%H%M%S).log"

# Fungsi untuk log dengan timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "======================================================"
log "  NYC TAXI DATABASE PIPELINE DIMULAI"
log "======================================================"

# STEP 1: Start database
log "STEP 1: Menjalankan Docker Compose..."
docker compose up -d

if [ $? -ne 0 ]; then
    log "ERROR: Docker Compose gagal dijalankan!"
    exit 1
fi

# Tunggu Postgres siap menerima koneksi
log "Menunggu PostgreSQL siap..."
sleep 5
log "STEP 1: SUCCESS"

# STEP 2: Jalankan pipeline Python
log "STEP 2: Menjalankan pipeline Python (main.py)..."
cd scripts
python main.py 2>&1 | tee -a "../$LOG_FILE"

if [ $? -ne 0 ]; then
    log "ERROR: Pipeline Python gagal!"
    exit 1
fi

cd ..
log "STEP 2: SUCCESS"


# done
log "======================================================"
log "  PIPELINE SELESAI! Log tersimpan di: $LOG_FILE"
log "======================================================"