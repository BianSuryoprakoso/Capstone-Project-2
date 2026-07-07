import os
from dotenv import load_dotenv
import psycopg2

# load_dotenv() akan membaca file .env supaya kita tidak perlu hardcode
# username/password di kode
load_dotenv()


class DatabaseConnection:
    """
    membuka koneksi ke PostgreSQL.
    """

    def __init__(self):
        #ambil semua info koneksi dari file .env
        self.host = os.getenv("POSTGRES_HOST", "localhost")
        self.port = os.getenv("POSTGRES_PORT", "5432")
        self.user = os.getenv("POSTGRES_USER")
        self.password = os.getenv("POSTGRES_PASSWORD")
        self.dbname = os.getenv("POSTGRES_DB")

    def connect(self):
        conn = psycopg2.connect(
            host=self.host,
            port=self.port,
            user=self.user,
            password=self.password,
            dbname=self.dbname,
        )
        return conn