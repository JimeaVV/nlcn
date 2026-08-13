"""Content-based scoring and time-constrained workout selection."""

from __future__ import annotations

import re
from typing import Any

import pandas as pd


SPLIT_MAP = {
    "Push": ("Chest", "Shoulders", "Triceps"),
    "Pull": ("Back", "Biceps", "Lats", "Forearms"),
    "Legs": ("Quadriceps", "Hamstrings", "Calves", "Glutes"),
    "Core": ("Abdominals",),
}

LEVEL_MAX_EXERCISES = {
    "Beginner": 5,
    "Intermediate": 7,
    "Pro": 9,
}

LEVEL_RANK = {
    "beginner": 0,
    "intermediate": 1,
    "pro": 2,
}

EXACT_LEVEL_SCORE = 6
LEVEL_DISTANCE_PENALTY = 3
FREE_WEIGHT_BONUS = 2

BARBELL_TIME_MINS = 12
MACHINE_OR_DUMBBELL_TIME_MINS = 10
OTHER_EQUIPMENT_TIME_MINS = 7

REQUIRED_COLUMNS = {"name", "muscle_group", "equipment", "level"}
RESULT_COLUMNS = [
    "name",
    "muscle_group",
    "equipment",
    "level",
    "estimated_time_mins",
    "score",
]


def estimate_exercise_time(equipment: Any) -> int:
    """Estimate exercise and rest time from the equipment category."""
    equipment_name = str(equipment).casefold()
    if "barbell" in equipment_name:
        return BARBELL_TIME_MINS
    if "machine" in equipment_name or "dumbbell" in equipment_name:
        return MACHINE_OR_DUMBBELL_TIME_MINS
    return OTHER_EQUIPMENT_TIME_MINS


def _validate_inputs(
    gym_df: pd.DataFrame,
    target_split: str,
    target_level: str,
    available_time_mins: int,
) -> None:
    missing = REQUIRED_COLUMNS.difference(gym_df.columns)
    if missing:
        columns = ", ".join(sorted(missing))
        raise RuntimeError(f"Exercise dataset is missing columns: {columns}")
    if target_split not in SPLIT_MAP:
        raise ValueError("Workout split must be Push, Pull, Legs or Core.")
    if target_level not in LEVEL_MAX_EXERCISES:
        raise ValueError("Experience level must be Beginner, Intermediate or Pro.")
    if not 15 <= available_time_mins <= 180:
        raise ValueError("Available workout time must be between 15 and 180 minutes.")


def _experience_score(exercise_level: Any, target_level: str) -> int:
    """Prefer the selected level while allowing the nearest-level fallback.

    The current dataset has no Pro-labelled rows and some muscle groups have no
    Beginner rows. A distance score makes that limitation explicit instead of
    silently treating every non-matching level as equally suitable.
    """
    exercise_rank = LEVEL_RANK.get(str(exercise_level).strip().casefold())
    target_rank = LEVEL_RANK[target_level.casefold()]
    if exercise_rank is None:
        return 0
    distance = abs(exercise_rank - target_rank)
    return max(0, EXACT_LEVEL_SCORE - distance * LEVEL_DISTANCE_PENALTY)


def _prepare_candidates(
    gym_df: pd.DataFrame,
    target_split: str,
    target_level: str,
) -> pd.DataFrame:
    dataframe = gym_df.copy()

    if "estimated_time_mins" not in dataframe.columns:
        dataframe["estimated_time_mins"] = dataframe["equipment"].apply(
            estimate_exercise_time
        )
    else:
        provided_times = pd.to_numeric(
            dataframe["estimated_time_mins"],
            errors="coerce",
        )
        fallback_times = dataframe["equipment"].apply(estimate_exercise_time)
        dataframe["estimated_time_mins"] = provided_times.where(
            provided_times > 0,
            fallback_times,
        ).astype(int)

    target_muscles = SPLIT_MAP[target_split]
    pattern = "|".join(re.escape(muscle) for muscle in target_muscles)
    dataframe = dataframe[
        dataframe["muscle_group"].str.contains(pattern, case=False, na=False)
    ].copy()

    if dataframe.empty:
        raise RuntimeError(
            f"No exercises are available for the {target_split} split."
        )

    dataframe["score"] = dataframe["level"].apply(
        lambda level: _experience_score(level, target_level)
    )
    free_weight_mask = dataframe["equipment"].str.contains(
        "barbell|dumbbell",
        case=False,
        na=False,
    )
    dataframe.loc[free_weight_mask, "score"] += FREE_WEIGHT_BONUS

    return dataframe.sort_values(
        by=["score", "estimated_time_mins", "name"],
        ascending=[False, True, True],
        kind="stable",
    )


def _group_by_target_muscle(
    candidates: pd.DataFrame,
    target_muscles: tuple[str, ...],
) -> dict[str, list[dict[str, Any]]]:
    return {
        muscle: candidates[
            candidates["muscle_group"].str.contains(
                re.escape(muscle),
                case=False,
                na=False,
            )
        ].to_dict("records")
        for muscle in target_muscles
    }


def _select_balanced_routine(
    grouped_candidates: dict[str, list[dict[str, Any]]],
    target_muscles: tuple[str, ...],
    available_time_mins: int,
    max_exercises: int,
) -> tuple[list[dict[str, Any]], int]:
    routine: list[dict[str, Any]] = []
    used_minutes = 0
    used_names: set[str] = set()

    while len(routine) < max_exercises:
        added_in_round = False

        for muscle in target_muscles:
            if len(routine) >= max_exercises:
                break

            candidates = grouped_candidates[muscle]
            while candidates:
                exercise = candidates.pop(0)
                name = str(exercise.get("name", "")).strip()
                normalized_name = name.casefold()
                if not normalized_name or normalized_name in used_names:
                    continue

                exercise_time = int(exercise["estimated_time_mins"])
                if used_minutes + exercise_time > available_time_mins:
                    # Keep looking: a later exercise may have a shorter estimate.
                    continue

                routine.append(exercise)
                used_names.add(normalized_name)
                used_minutes += exercise_time
                added_in_round = True
                break

        if not added_in_round:
            break

    return routine, used_minutes


def recommend_workout_routine(
    gym_df: pd.DataFrame,
    target_split: str,
    target_level: str,
    available_time_mins: int = 45,
) -> tuple[pd.DataFrame, int]:
    """Return a level-aware, muscle-balanced routine within the exact time limit."""
    _validate_inputs(gym_df, target_split, target_level, available_time_mins)

    target_muscles = SPLIT_MAP[target_split]
    candidates = _prepare_candidates(gym_df, target_split, target_level)
    grouped_candidates = _group_by_target_muscle(candidates, target_muscles)
    routine, used_minutes = _select_balanced_routine(
        grouped_candidates,
        target_muscles,
        available_time_mins,
        LEVEL_MAX_EXERCISES[target_level],
    )

    if not routine:
        raise RuntimeError("No exercises fit the requested workout constraints.")

    return pd.DataFrame(routine)[RESULT_COLUMNS], used_minutes


if __name__ == "__main__":
    if __package__:
        from .tienxuly import load_and_preprocess_data
    else:
        from tienxuly import load_and_preprocess_data

    _, gym_data = load_and_preprocess_data()
    if gym_data is None:
        raise SystemExit("Could not load exercise dataset.")
    routine, total_time = recommend_workout_routine(
        gym_data,
        "Push",
        "Beginner",
        available_time_mins=45,
    )
    print(f"Total estimated time: {total_time} minutes")
    print(routine)
