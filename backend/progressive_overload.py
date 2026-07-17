"""Rule-based progressive overload for a 3-set, 8-12 rep range."""

from typing import Dict, List

TARGET_SETS = 3
MIN_REPS = 8
MAX_REPS = 12
WEIGHT_INCREMENT_KG = 2.5


def suggest_progressive_overload(
    current_weight: float,
    reps_per_set: List[int],
    difficulty: str,
) -> Dict[str, object]:
    if current_weight < 0:
        raise ValueError("Current weight cannot be negative.")
    if len(reps_per_set) != TARGET_SETS:
        raise ValueError("Exactly 3 sets are required.")
    if any(rep < 0 or rep > 30 for rep in reps_per_set):
        raise ValueError("Each set must contain between 0 and 30 reps.")

    difficulty_key = difficulty.strip().lower()
    allowed = {"easy", "moderate", "hard", "failure"}
    if difficulty_key not in allowed:
        raise ValueError(
            "Difficulty must be Easy, Moderate, Hard or Failure."
        )

    total_reps = sum(reps_per_set)
    completed_3x12 = all(rep >= MAX_REPS for rep in reps_per_set)
    below_minimum = any(rep < MIN_REPS for rep in reps_per_set)

    next_weight = current_weight
    next_rep_target = MAX_REPS
    action = "maintain"

    if completed_3x12 and difficulty_key in {"easy", "moderate"}:
        next_weight = current_weight + WEIGHT_INCREMENT_KG
        next_rep_target = MIN_REPS
        action = "increase_weight"
        message = (
            "Completed 3x12 with manageable difficulty. Increase the load by "
            "2.5kg next session and restart within the 8-12 rep range."
        )
    elif completed_3x12 and difficulty_key == "hard":
        action = "maintain_weight"
        message = (
            "Completed 3x12, but effort was high. Keep the same load for one "
            "more session before increasing it."
        )
    elif difficulty_key == "failure" or total_reps < 24 or below_minimum:
        next_weight = max(0.0, current_weight - WEIGHT_INCREMENT_KG)
        next_rep_target = MIN_REPS
        action = "decrease_weight"
        message = (
            "Performance fell below the target rep range. Reduce the load by "
            "2.5kg and prioritize controlled technique."
        )
    else:
        action = "increase_reps"
        message = (
            "Keep the same load and try to add reps until all three sets reach "
            "12 reps."
        )

    return {
        "current_weight": round(current_weight, 2),
        "set_1_reps": reps_per_set[0],
        "set_2_reps": reps_per_set[1],
        "set_3_reps": reps_per_set[2],
        "total_reps": total_reps,
        "difficulty": difficulty.title(),
        "target_sets": TARGET_SETS,
        "rep_range_min": MIN_REPS,
        "rep_range_max": MAX_REPS,
        "next_weight": round(next_weight, 2),
        "next_rep_target": next_rep_target,
        "action": action,
        "message": message,
    }
