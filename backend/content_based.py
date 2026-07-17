import pandas as pd
from tienxuly import load_and_preprocess_data

SPLIT_MAP = {
    "Push": ["Chest", "Shoulders", "Triceps"],
    "Pull": ["Back", "Biceps", "Lats", "Forearms"],
    "Legs": ["Quadriceps", "Hamstrings", "Calves", "Glutes"],
    "Core": ["Abdominals"],
}

LEVEL_MAX_EXERCISES = {
    "Beginner": 5,
    "Intermediate": 7,
    "Pro": 9,
}


def estimate_exercise_time(equipment):
    """Estimate training time including rest based on equipment."""
    equipment = str(equipment).lower()
    if "barbell" in equipment:
        return 12
    if "machine" in equipment or "dumbbell" in equipment:
        return 10
    return 7


def recommend_workout_routine(
    gym_df,
    target_split,
    target_level,
    available_time_mins=45,
):
    """
    Content-based filtering + time-constrained greedy selection.

    The routine is capped by level so a long input such as 120 minutes does not
    produce an unrealistic number of exercises. The main exercise block is also
    capped at 90 minutes; remaining time may be used for warm-up, rest and
    cool-down.
    """
    df = gym_df.copy()
    df["score"] = 0

    if "estimated_time_mins" not in df.columns:
        df["estimated_time_mins"] = df["equipment"].apply(
            estimate_exercise_time
        )

    target_muscles = SPLIT_MAP.get(target_split, [target_split])
    pattern = "|".join(target_muscles)
    df = df[
        df["muscle_group"].str.contains(pattern, case=False, na=False)
    ].copy()

    df.loc[
        df["level"].str.contains(target_level, case=False, na=False),
        "score",
    ] += 5
    df.loc[
        df["equipment"].str.contains(
            "barbell|dumbbell", case=False, na=False
        ),
        "score",
    ] += 2

    recommended = df.sort_values(by="score", ascending=False)

    max_exercises = LEVEL_MAX_EXERCISES.get(target_level, 7)
    effective_time_limit = min(max(int(available_time_mins), 15), 90)

    grouped_data = {
        muscle: recommended[
            recommended["muscle_group"].str.contains(
                muscle, case=False, na=False
            )
        ].to_dict("records")
        for muscle in target_muscles
    }

    final_routine = []
    current_time = 0
    used_names = set()

    while current_time < effective_time_limit:
        if len(final_routine) >= max_exercises:
            break

        added_in_round = False

        for muscle in target_muscles:
            if len(final_routine) >= max_exercises:
                break

            while grouped_data[muscle]:
                exercise = grouped_data[muscle].pop(0)
                name = str(exercise.get("name", "")).strip().lower()

                if not name or name in used_names:
                    continue

                exercise_time = int(exercise["estimated_time_mins"])
                if current_time + exercise_time <= effective_time_limit + 3:
                    final_routine.append(exercise)
                    used_names.add(name)
                    current_time += exercise_time
                    added_in_round = True
                break

        if not added_in_round:
            break

    result_df = pd.DataFrame(final_routine)
    if not result_df.empty:
        columns = [
            "name",
            "muscle_group",
            "equipment",
            "level",
            "estimated_time_mins",
            "score",
        ]
        return result_df[columns], current_time

    return pd.DataFrame(), 0


if __name__ == "__main__":
    _, gym_data = load_and_preprocess_data()
    if gym_data is not None:
        routine, total_time = recommend_workout_routine(
            gym_data,
            "Push",
            "Beginner",
            available_time_mins=120,
        )
        print(f"Total estimated time: {total_time} minutes")
        print(routine)
