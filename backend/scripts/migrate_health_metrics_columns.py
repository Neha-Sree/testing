"""One-off SQLite migration for health_metrics columns (run if DB predates new fields)."""
import sys
from pathlib import Path

# Allow `python scripts/migrate_health_metrics_columns.py` from backend/
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import text

from app.database import engine


def main() -> None:
    with engine.begin() as connection:
        rows = connection.execute(text("PRAGMA table_info(health_metrics)")).fetchall()
        if not rows:
            print("health_metrics table missing; start the app once to create tables.")
            return
        cols = {row[1] for row in rows}
        if "oxygen_saturation" not in cols:
            connection.execute(text("ALTER TABLE health_metrics ADD COLUMN oxygen_saturation FLOAT"))
            print("Added oxygen_saturation")
        if "fetal_movement" not in cols:
            connection.execute(text("ALTER TABLE health_metrics ADD COLUMN fetal_movement VARCHAR(30)"))
            print("Added fetal_movement")
        if "swelling" not in cols:
            connection.execute(text("ALTER TABLE health_metrics ADD COLUMN swelling VARCHAR(40)"))
            print("Added swelling")
        if cols >= {"oxygen_saturation", "fetal_movement", "swelling"}:
            print("health_metrics columns already present.")


if __name__ == "__main__":
    main()
