from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

logger = logging.getLogger("optifit.data")

DATA_DIR = Path(__file__).resolve().parent / "data"
FOOD_DATA_PATH = DATA_DIR / "final-food-dataset.csv"
GYM_DATA_PATH = DATA_DIR / "gym-ex-dataset.csv"

FOOD_COLUMNS = {
    "name",
    "category",
    "macro_group",
    "calories_per_100g",
    "protein_g",
    "carb_g",
    "fat_g",
    "max_amount_g",
    "suggested_prep",
}
FOOD_NUMERIC_COLUMNS = {
    "calories_per_100g",
    "protein_g",
    "carb_g",
    "fat_g",
    "max_amount_g",
}
GYM_COLUMNS = {"name", "muscle_group", "equipment", "level"}


def _clean_column_names(dataframe: pd.DataFrame) -> pd.DataFrame:
    dataframe = dataframe.copy()
    dataframe.columns = (
        dataframe.columns.str.strip().str.replace("\n", "", regex=False).str.replace(
            "\r", "", regex=False
        )
    )
    return dataframe


def _require_columns(
    dataframe: pd.DataFrame,
    required: set[str],
    dataset_name: str,
) -> None:
    missing = required.difference(dataframe.columns)
    if missing:
        columns = ", ".join(sorted(missing))
        raise ValueError(f"{dataset_name} is missing columns: {columns}")


def load_and_preprocess_data(
    food_path: str | Path = FOOD_DATA_PATH,
    gym_path: str | Path = GYM_DATA_PATH,
) -> tuple[pd.DataFrame | None, pd.DataFrame | None]:
    try:
        food_df = _clean_column_names(pd.read_csv(Path(food_path)))
        gym_df = _clean_column_names(pd.read_csv(Path(gym_path)))

        _require_columns(food_df, FOOD_COLUMNS, "Food dataset")
        _require_columns(gym_df, GYM_COLUMNS, "Exercise dataset")

        for column in FOOD_NUMERIC_COLUMNS:
            food_df[column] = pd.to_numeric(food_df[column], errors="coerce")

        food_df = food_df.dropna(subset=list(FOOD_COLUMNS))
        food_df = food_df.drop_duplicates(subset=["name"])
        gym_df = gym_df.dropna(subset=list(GYM_COLUMNS)).drop_duplicates()

        for column in ("name", "category", "macro_group", "suggested_prep"):
            food_df[column] = food_df[column].astype(str).str.strip()
        for column in GYM_COLUMNS:
            gym_df[column] = gym_df[column].astype(str).str.strip()

        return food_df.reset_index(drop=True), gym_df.reset_index(drop=True)
    except (FileNotFoundError, OSError, pd.errors.ParserError, ValueError):
        logger.exception("Unable to load or preprocess recommendation datasets.")
        return None, None


if __name__ == "__main__":
    food_data, gym_data = load_and_preprocess_data()
    if food_data is None or gym_data is None:
        raise SystemExit("Could not load recommendation datasets.")
    print("Food columns:", list(food_data.columns))
    print("Gym columns:", list(gym_data.columns))
