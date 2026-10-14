#!/usr/bin/env python3
"""
run_etl.py - wrapper orkestrasi untuk standalone_etl.py (bawaan repo).

Logika ETL (SQL, transformasi, urutan langkah) TIDAK diubah.
Yang disesuaikan hanya hal orkestrasi:
  1. Koneksi DB dibaca dari environment (.env), bukan hardcode.
  2. Path CSV: ETL asli membaca data/raw/Dataset/*.csv, sedangkan di repo
     file CSV ada di folder data/. Path dialihkan ke DATA_DIR.
  3. Exit code non-zero kalau ETL gagal, supaya pipeline berhenti.
"""
import os
import sys

sys.path.insert(0, "/app")

import pandas as pd
import pymssql

DATA_DIR = os.environ.get("DATA_DIR", "/app/data")

_orig_read_csv = pd.read_csv


def _read_csv(path, *args, **kwargs):
    new_path = os.path.join(DATA_DIR, os.path.basename(str(path)))
    return _orig_read_csv(new_path, *args, **kwargs)


pd.read_csv = _read_csv

import standalone_etl as etl  # noqa: E402


def get_conn():
    return pymssql.connect(
        server=os.environ["MSSQL_HOST"],
        port=int(os.environ.get("MSSQL_PORT", "1433")),
        database=os.environ["MSSQL_DB"],
        user=os.environ["MSSQL_USER"],
        password=os.environ["MSSQL_SA_PASSWORD"],
        timeout=30,
    )


etl.get_sql_connection = get_conn

if __name__ == "__main__":
    etl.logging.info("run_etl.py: menjalankan standalone_etl.run_complete_etl()")
    ok = etl.run_complete_etl()
    sys.exit(0 if ok else 1)