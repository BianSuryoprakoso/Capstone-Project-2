import os
import csv
from datetime import datetime
from database import DatabaseConnection


class QueryRunner:
    # Run query SQL ke PostgreSQL, dan simpan hasilnya ke file CSV dan Markdown.


    def __init__(self, db: DatabaseConnection, output_dir: str):
        self.db = db
        self.output_dir = output_dir

        # Buat folder output kalau belum ada
        os.makedirs(self.output_dir, exist_ok=True)

    def run_query(self, label: str, sql: str):
        """
        label : nama/judul query
        sql   : query SQL-nya
        """
        print(f"\n>>> {label}")

        conn = self.db.connect()
        cur = conn.cursor()

        try:
            # Jalankan query
            cur.execute(sql)

            # Ambil nama kolom
            columns = [desc[0] for desc in cur.description]

            # Ambil semua baris hasil
            rows = cur.fetchall()

            print(f"Hasil: {len(rows)} baris")

            # Simpan ke CSV
            self._save_csv(label, columns, rows)

            # Simpan ke Markdown
            self._save_markdown(label, columns, rows)

        except Exception as e:
            print(f"ERROR pada {label}: {e}")

        finally:
            cur.close()
            conn.close()

    def _save_csv(self, label: str, columns: list, rows: list):
        """Simpan hasil query ke file CSV."""
        filepath = os.path.join(self.output_dir, f"{label}.csv")

        with open(filepath, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(columns)  # tulis header kolom
            writer.writerows(rows)    # tulis semua baris data

        print(f"CSV : {filepath}")

    def _save_markdown(self, label: str, columns: list, rows: list):
        """Simpan hasil query ke file Markdown sebagai tabel."""
        filepath = os.path.join(self.output_dir, f"{label}.md")

        with open(filepath, "w", encoding="utf-8") as f:
            # Tulis judul
            f.write(f"# {label}\n\n")
            f.write(f"*Dijalankan pada: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}*\n\n")

            # Tulis header tabel markdown
            f.write("| " + " | ".join(columns) + " |\n")
            f.write("| " + " | ".join(["---"] * len(columns)) + " |\n")

            # Tulis setiap baris data
            for row in rows:
                # Convert nilai ke string supaya tidak error
                row_str = [str(v) if v is not None else "" for v in row]
                f.write("| " + " | ".join(row_str) + " |\n")

            f.write(f"\n*Total: {len(rows)} baris*\n")

        print(f"MD  : {filepath}")