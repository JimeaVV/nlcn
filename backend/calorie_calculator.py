"""Mifflin-St Jeor calorie calculations used by meal recommendation."""

from math import floor


ACTIVITY_FACTORS = frozenset({1.2, 1.375, 1.55, 1.725, 1.9})
CALORIE_DEFICIT = 500
GENDER_CONSTANTS = {
    "male": 5,
    "m": 5,
    "nam": 5,
    "female": -161,
    "f": -161,
    "nu": -161,
}


def round_half_up(value: float) -> int:
    return floor(value + 0.5)


def calculate_target_calories(
    age: int,
    gender: str,
    weight: float,
    height: float,
    activity_level: float,
) -> tuple[int, int, int]:
    if not 13 <= age <= 100:
        raise ValueError("Age must be between 13 and 100.")
    if not 0 < weight <= 500:
        raise ValueError("Weight must be between 0 and 500 kg.")
    if not 0 < height <= 300:
        raise ValueError("Height must be between 0 and 300 cm.")
    if activity_level not in ACTIVITY_FACTORS:
        raise ValueError("Activity level is not supported.")

    gender_key = gender.strip().lower()
    gender_constant = GENDER_CONSTANTS.get(gender_key)
    if gender_constant is None:
        raise ValueError("Gender must be male or female.")

    bmr = (10 * weight) + (6.25 * height) - (5 * age) + gender_constant
    tdee = bmr * activity_level
    target_calories = tdee - CALORIE_DEFICIT

    if target_calories <= 0:
        raise ValueError("Calculated calorie target must be greater than 0.")

    return (
        round_half_up(bmr),
        round_half_up(tdee),
        round_half_up(target_calories),
    )
