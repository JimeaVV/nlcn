"""Refresh the checked-in Flutter dataset; Python is not needed by the app."""

import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NUMERIC_FOOD_FIELDS = {
    "calories_per_100g", "protein_g", "carb_g", "fat_g", "max_amount_g"
}


def read_rows(filename: str, numeric_fields: set[str]) -> list[dict]:
    rows = []
    seen = set()
    with (ROOT / "backend" / "data" / filename).open(
        encoding="utf-8-sig", newline=""
    ) as source:
        for raw_row in csv.DictReader(source):
            row = {key.strip(): value.strip() for key, value in raw_row.items()}
            for key in numeric_fields:
                row[key] = float(row[key])
            # The source food loader deduplicates by name, exercises by full row.
            identity = row["name"] if numeric_fields else tuple(row.items())
            if identity not in seen:
                seen.add(identity)
                rows.append(row)
    return rows


def main() -> None:
    data = {
        "schema_version": 1,
        "foods": read_rows("final-food-dataset.csv", NUMERIC_FOOD_FIELDS),
        "exercises": read_rows("gym-ex-dataset.csv", set()),
    }
    destination = ROOT / "assets" / "data" / "recommendations.json"
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(
        json.dumps(data, ensure_ascii=False, allow_nan=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Bundled {len(data['foods'])} foods and {len(data['exercises'])} exercises.")


if __name__ == "__main__":
    main()
