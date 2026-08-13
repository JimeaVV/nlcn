"""
Protein-first Branch & Bound meal recommendation.

Main objective for cutting:
1. Reach daily protein target based on body weight.
2. Stay close to calorie target.
3. Keep meals structurally realistic.
4. Avoid repeating lunch/dinner protein and starch when possible.
5. Limit added-fat portions to 15g per meal.
"""

from __future__ import annotations

import math
import random
import time
from typing import Any, Sequence

Food = dict[str, Any]
MealResult = dict[str, Any]
FoodSelection = tuple[Food, str, int]
CandidateGroup = tuple[str, Sequence[Food], bool]

STEP_G = 25
FAT_PORTIONS_G = (0, 5, 10, 15)
TIME_LIMIT_SECONDS = 1.5
DEFAULT_PROTEIN_PER_KG = 1.8
CALORIE_OVERSHOOT_RATIO = 1.12
REQUIRED_CANDIDATE_LIMIT = 6
OPTIONAL_CANDIDATE_LIMIT = 4

PROTEIN_SHORTAGE_WEIGHT = 120.0
PROTEIN_EXCESS_WEIGHT = 15.0
PROTEIN_EXCESS_RATIO = 1.20
CALORIE_ERROR_WEIGHT = 1.0
MIN_CARB_CALORIE_RATIO = 0.20
MAX_FAT_CALORIE_RATIO = 0.40
MACRO_PENALTY_WEIGHT = 50.0
REPEATED_CHEESE_PENALTY = 20.0

MEAL_RATIOS = {
    "Breakfast": 0.30,
    "Lunch": 0.35,
    "Dinner": 0.35,
}

MEAL_RULES = {
    "Breakfast": {
        "required_groups": ("starch", "dairyegg", "fruit"),
        "optional_groups": ("fat",),
    },
    "Lunch": {
        "required_groups": ("starch", "meat", "veggie"),
        "optional_groups": ("fat",),
    },
    "Dinner": {
        "required_groups": ("starch", "meat", "veggie"),
        "optional_groups": ("fat",),
    },
}

PORTION_RANGES = {
    "starch": (75, 250),
    "meat": (100, 250),
    "dairyegg": (50, 250),
    "veggie": (100, 250),
    "fruit": (75, 200),
    "fat": (0, 15),
}

LUNCH_DINNER_STARCH_KEYWORDS = (
    "rice",
    "potato",
    "sweet potato",
    "quinoa",
    "bread",
    "pasta",
    "noodle",
    "couscous",
    "barley",
    "corn",
)


def _number(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _group(food: Food) -> str:
    return str(food.get("macro_group", "")).strip().lower()


def _food_name(food: Food) -> str:
    return str(food.get("name", "")).strip()


def _max_serving(food: Food, group: str) -> int:
    dataset_max = max(1, int(_number(food.get("max_amount_g"), 200)))
    _, configured_max = PORTION_RANGES[group]
    return min(dataset_max, configured_max)


def _portion_options(food: Food, group: str) -> list[int]:
    if group == "fat":
        dataset_max = int(_number(food.get("max_amount_g"), 15))
        max_allowed = min(dataset_max, PORTION_RANGES["fat"][1])
        return [grams for grams in FAT_PORTIONS_G if grams <= max_allowed]

    minimum, _ = PORTION_RANGES[group]
    maximum = _max_serving(food, group)

    # Some concentrated foods have a dataset limit below the usual serving
    # minimum. In that case the dataset limit is authoritative.
    if maximum < minimum:
        return [maximum]

    return list(range(minimum, maximum + 1, STEP_G))


def _nutrition(food: Food, grams: int) -> tuple[float, float, float, float]:
    factor = grams / 100.0
    return (
        _number(food.get("calories_per_100g")) * factor,
        _number(food.get("protein_g")) * factor,
        _number(food.get("carb_g")) * factor,
        _number(food.get("fat_g")) * factor,
    )


def _candidate_score(food: Food, group: str, meal_name: str) -> float:
    calories = max(_number(food.get("calories_per_100g")), 1.0)
    protein = _number(food.get("protein_g"))
    carbs = _number(food.get("carb_g"))
    fat = _number(food.get("fat_g"))
    name = _food_name(food).lower()

    if group in {"meat", "dairyegg"}:
        score = (protein / calories) * 4.0
    elif group == "starch":
        score = carbs / calories
    elif group in {"fruit", "veggie"}:
        score = (carbs + 5.0) / calories
    else:
        score = fat / calories

    if "cheese" in name:
        score -= 0.10

    if meal_name in {"Lunch", "Dinner"} and group == "starch":
        if any(keyword in name for keyword in LUNCH_DINNER_STARCH_KEYWORDS):
            score += 0.15
        if "oat" in name:
            score -= 0.18

    return score


def _prepare_pools(food_list: Sequence[Food]) -> dict[str, list[Food]]:
    pools: dict[str, list[Food]] = {
        "starch": [],
        "meat": [],
        "dairyegg": [],
        "veggie": [],
        "fruit": [],
        "fat": [],
    }

    seen: set[str] = set()

    for food in food_list:
        name = _food_name(food)
        normalized_name = name.lower()
        group = _group(food)

        if not name or normalized_name in seen or group not in pools:
            continue
        if _number(food.get("calories_per_100g")) <= 0:
            continue
        if _number(food.get("max_amount_g")) <= 0:
            continue

        seen.add(normalized_name)
        pools[group].append(dict(food))

    return pools


def _pick_candidates(
    pool: Sequence[Food],
    group: str,
    meal_name: str,
    limit: int,
    rng: random.Random,
    excluded_names: set[str],
) -> list[Food]:
    filtered = [
        food for food in pool
        if _food_name(food).lower() not in excluded_names
    ]

    filtered.sort(
        key=lambda food: _candidate_score(food, group, meal_name),
        reverse=True,
    )

    if len(filtered) <= limit:
        return filtered

    top_count = max(2, limit // 2)
    top = filtered[:top_count]
    remaining = filtered[top_count:]
    random_count = min(limit - len(top), len(remaining))

    return top + rng.sample(remaining, random_count)


def _meal_score(
    calories: float,
    protein: float,
    carbs: float,
    fat: float,
    target_calories: float,
    target_protein: float,
    selected: Sequence[FoodSelection],
) -> float:
    """
    Lower is better.

    Protein shortage is intentionally weighted much more heavily than
    calorie difference, because the app targets cutting while preserving muscle.
    """
    protein_shortage = max(0.0, target_protein - protein)
    protein_excess = max(0.0, protein - target_protein * PROTEIN_EXCESS_RATIO)
    calorie_error = abs(calories - target_calories)

    carb_ratio = (carbs * 4) / max(calories, 1.0)
    fat_ratio = (fat * 9) / max(calories, 1.0)

    macro_penalty = 0.0
    if carb_ratio < MIN_CARB_CALORIE_RATIO:
        macro_penalty += (
            MIN_CARB_CALORIE_RATIO - carb_ratio
        ) * MACRO_PENALTY_WEIGHT
    if fat_ratio > MAX_FAT_CALORIE_RATIO:
        macro_penalty += (
            fat_ratio - MAX_FAT_CALORIE_RATIO
        ) * MACRO_PENALTY_WEIGHT

    cheese_count = sum(
        1
        for food, _, grams in selected
        if grams > 0 and "cheese" in _food_name(food).lower()
    )
    repetition_penalty = max(0, cheese_count - 1) * REPEATED_CHEESE_PENALTY

    return (
        protein_shortage * PROTEIN_SHORTAGE_WEIGHT
        + protein_excess * PROTEIN_EXCESS_WEIGHT
        + calorie_error * CALORIE_ERROR_WEIGHT
        + macro_penalty
        + repetition_penalty
    )


def _build_result_item(food: Food, group: str, grams: int) -> Food:
    calories, protein, carbs, fat = _nutrition(food, grams)

    item = dict(food)
    item.update(
        {
            "portion_g": grams,
            "serving_calo": round(calories, 2),
            "serving_protein": round(protein, 2),
            "serving_carb": round(carbs, 2),
            "serving_fat": round(fat, 2),
            "display_name": f"{grams}g {_food_name(food)}",
            "food_group": group,
            "suggested_prep": str(food.get("suggested_prep", "")).strip(),
        }
    )
    return item


def branch_and_bound_meal(
    group_candidates: Sequence[CandidateGroup],
    target_calories: float,
    target_protein: float,
    time_limit: float = TIME_LIMIT_SECONDS,
) -> MealResult:
    started = time.perf_counter()
    best_score = math.inf
    best_selection: list[FoodSelection] = []

    max_remaining_protein = [0.0] * (len(group_candidates) + 1)

    for index in range(len(group_candidates) - 1, -1, -1):
        group, candidates, optional = group_candidates[index]
        maximum = 0.0

        for food in candidates:
            for grams in _portion_options(food, group):
                maximum = max(maximum, _nutrition(food, grams)[1])

        max_remaining_protein[index] = (
            max_remaining_protein[index + 1] + maximum
        )

    def search(
        index: int,
        calories: float,
        protein: float,
        carbs: float,
        fat: float,
        selected: list[FoodSelection],
    ) -> None:
        nonlocal best_score, best_selection

        if time.perf_counter() - started > time_limit:
            return

        optimistic_protein = protein + max_remaining_protein[index]
        unavoidable_shortage = max(0.0, target_protein - optimistic_protein)

        if unavoidable_shortage * PROTEIN_SHORTAGE_WEIGHT > best_score:
            return

        if index == len(group_candidates):
            score = _meal_score(
                calories,
                protein,
                carbs,
                fat,
                target_calories,
                target_protein,
                selected,
            )
            if score < best_score:
                best_score = score
                best_selection = list(selected)
            return

        group, candidates, optional = group_candidates[index]

        if optional:
            search(index + 1, calories, protein, carbs, fat, selected)

        for food in candidates:
            for grams in _portion_options(food, group):
                if grams == 0:
                    continue

                add_calories, add_protein, add_carbs, add_fat = _nutrition(
                    food, grams
                )
                new_calories = calories + add_calories

                # Small overshoot is allowed to avoid sacrificing too much protein.
                if new_calories > target_calories * CALORIE_OVERSHOOT_RATIO:
                    continue

                selected.append((food, group, grams))
                search(
                    index + 1,
                    new_calories,
                    protein + add_protein,
                    carbs + add_carbs,
                    fat + add_fat,
                    selected,
                )
                selected.pop()

    search(0, 0.0, 0.0, 0.0, 0.0, [])

    if not best_selection:
        raise ValueError(
            "No feasible meal combination was found within the search limit."
        )

    items = [
        _build_result_item(food, group, grams)
        for food, group, grams in best_selection
        if grams > 0
    ]

    total_calo = round(sum(item["serving_calo"] for item in items), 2)
    total_protein = round(sum(item["serving_protein"] for item in items), 2)
    total_carb = round(sum(item["serving_carb"] for item in items), 2)
    total_fat = round(sum(item["serving_fat"] for item in items), 2)

    return {
        "items": items,
        "target_calo": round(target_calories, 2),
        "target_protein": round(target_protein, 2),
        "calo": total_calo,
        "protein": total_protein,
        "carb": total_carb,
        "fat": total_fat,
        "protein_difference": round(total_protein - target_protein, 2),
        "score": round(best_score, 3) if math.isfinite(best_score) else None,
    }


def _meal_candidate_groups(
    pools: dict[str, list[Food]],
    meal_name: str,
    rng: random.Random,
    used_starches: set[str],
    used_proteins: set[str],
) -> list[CandidateGroup]:
    rules = MEAL_RULES[meal_name]
    groups: list[CandidateGroup] = []

    for group in rules["required_groups"]:
        excluded_names: set[str] = set()
        if meal_name == "Dinner" and group == "starch":
            excluded_names = used_starches
        elif meal_name == "Dinner" and group == "meat":
            excluded_names = used_proteins

        candidates = _pick_candidates(
            pools[group],
            group,
            meal_name,
            limit=REQUIRED_CANDIDATE_LIMIT,
            rng=rng,
            excluded_names=excluded_names,
        )
        if not candidates and excluded_names:
            candidates = _pick_candidates(
                pools[group],
                group,
                meal_name,
                limit=REQUIRED_CANDIDATE_LIMIT,
                rng=rng,
                excluded_names=set(),
            )
        if not candidates:
            raise ValueError(f"No foods available for required group: {group}")

        groups.append((group, candidates, False))

    for group in rules["optional_groups"]:
        candidates = _pick_candidates(
            pools[group],
            group,
            meal_name,
            limit=OPTIONAL_CANDIDATE_LIMIT,
            rng=rng,
            excluded_names=set(),
        )
        if candidates:
            groups.append((group, candidates, True))

    return groups


def _record_lunch_dinner_foods(
    meal: MealResult,
    used_starches: set[str],
    used_proteins: set[str],
) -> None:
    for item in meal["items"]:
        item_name = str(item.get("name", "")).lower()
        item_group = str(item.get("food_group", "")).lower()
        if item_group == "starch":
            used_starches.add(item_name)
        elif item_group == "meat":
            used_proteins.add(item_name)


def _empty_plan(
    daily_calories: float,
    body_weight_kg: float,
    protein_per_kg: float,
) -> MealResult:
    return {
        "meals": {},
        "target_calo": round(daily_calories, 2),
        "protein_target": round(body_weight_kg * protein_per_kg, 2),
        "protein_per_kg": round(protein_per_kg, 2),
        "body_weight_kg": round(body_weight_kg, 2),
        "total_calo": 0.0,
        "total_protein": 0.0,
        "total_carb": 0.0,
        "total_fat": 0.0,
        "calorie_difference": 0.0,
        "protein_difference": 0.0,
        "time": 0.0,
    }


def _add_meal_totals(plan: MealResult, meal: MealResult) -> None:
    plan["total_calo"] += meal["calo"]
    plan["total_protein"] += meal["protein"]
    plan["total_carb"] += meal["carb"]
    plan["total_fat"] += meal["fat"]


def generate_meal_plan(
    food_list: Sequence[Food],
    daily_calories: float,
    body_weight_kg: float,
    protein_per_kg: float = DEFAULT_PROTEIN_PER_KG,
    seed: int | None = None,
) -> MealResult:
    if not food_list:
        raise ValueError("Food list is empty.")
    if daily_calories <= 0:
        raise ValueError("Daily calories must be greater than 0.")
    if body_weight_kg <= 0:
        raise ValueError("Body weight must be greater than 0.")
    if protein_per_kg <= 0:
        raise ValueError("Protein per kg must be greater than 0.")

    pools = _prepare_pools(food_list)
    # No seed means a fresh plan on each request. Tests and experiments can
    # pass a seed when they need a reproducible recommendation.
    rng = random.Random(seed)

    daily_protein_target = body_weight_kg * protein_per_kg

    plan = _empty_plan(daily_calories, body_weight_kg, protein_per_kg)

    started = time.perf_counter()
    used_lunch_dinner_starches: set[str] = set()
    used_lunch_dinner_proteins: set[str] = set()

    for meal_name, ratio in MEAL_RATIOS.items():
        meal_target_calories = daily_calories * ratio
        meal_target_protein = daily_protein_target * ratio
        candidate_groups = _meal_candidate_groups(
            pools,
            meal_name,
            rng,
            used_lunch_dinner_starches,
            used_lunch_dinner_proteins,
        )

        meal = branch_and_bound_meal(
            candidate_groups,
            target_calories=meal_target_calories,
            target_protein=meal_target_protein,
        )

        plan["meals"][meal_name] = meal

        if meal_name in {"Lunch", "Dinner"}:
            _record_lunch_dinner_foods(
                meal,
                used_lunch_dinner_starches,
                used_lunch_dinner_proteins,
            )

        _add_meal_totals(plan, meal)

    plan["time"] = round(time.perf_counter() - started, 6)
    plan["total_calo"] = round(plan["total_calo"], 2)
    plan["total_protein"] = round(plan["total_protein"], 2)
    plan["total_carb"] = round(plan["total_carb"], 2)
    plan["total_fat"] = round(plan["total_fat"], 2)
    plan["calorie_difference"] = round(
        plan["total_calo"] - daily_calories,
        2,
    )
    plan["protein_difference"] = round(
        plan["total_protein"] - daily_protein_target,
        2,
    )

    return plan


if __name__ == "__main__":
    if __package__:
        from .tienxuly import load_and_preprocess_data
    else:
        from tienxuly import load_and_preprocess_data

    food_data, _ = load_and_preprocess_data()

    if food_data is None:
        raise SystemExit("Could not load food dataset.")

    result = generate_meal_plan(
        food_data.to_dict("records"),
        daily_calories=2100,
        body_weight_kg=70,
        protein_per_kg=DEFAULT_PROTEIN_PER_KG,
        seed=42,
    )

    print(
        f"TOTAL: {result['total_calo']:.0f}/{result['target_calo']:.0f} kcal | "
        f"P {result['total_protein']:.1f}/{result['protein_target']:.1f}g | "
        f"C {result['total_carb']:.1f}g | "
        f"F {result['total_fat']:.1f}g"
    )
