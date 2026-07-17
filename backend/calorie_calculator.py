def round_half_up(n: float) -> int:
    return int(n + 0.5)

def calculate_target_calories(age: int, gender: str, weight: float, height: float, activity_level: float):

    gender_lower = gender.strip().lower()
    
    if gender_lower in ("nam", "male", "m"):
        bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5
    elif gender_lower in ("nữ", "nu", "female", "f"):
        bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161
    else:
        bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5
        
    tdee = bmr * activity_level
    
    target_calories = tdee - 500
    
    return round_half_up(bmr), round_half_up(tdee), round_half_up(target_calories)
