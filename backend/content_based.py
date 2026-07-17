import pandas as pd
import math
from tienxuly import load_and_preprocess_data

SPLIT_MAP = {
    "Push": ["Chest", "Shoulders", "Triceps"],
    "Pull": ["Back", "Biceps", "Lats", "Forearms"],
    "Legs": ["Quadriceps", "Hamstrings", "Calves", "Glutes"],
    "Core": ["Abdominals"]
}

def estimate_exercise_time(equipment):
    """
    Heuristic: Nội suy thời gian tập (bao gồm cả nghỉ) dựa vào loại dụng cụ.
    """
    equipment = str(equipment).lower()
    if 'barbell' in equipment: 
        return 12 
    elif 'machine' in equipment or 'dumbbell' in equipment: 
        return 10 
    else: 
        return 7  

def recommend_workout_routine(gym_df, target_split, target_level, available_time_mins=45):
    """
    Hệ thống gợi ý bài tập: Lọc Content-Based + Tối ưu Thời gian (Time-Constrained Greedy)
    """
    df = gym_df.copy()
    df['score'] = 0
    
    if 'estimated_time_mins' not in df.columns:
        df['estimated_time_mins'] = df['equipment'].apply(estimate_exercise_time)

    target_muscles = SPLIT_MAP.get(target_split, [target_split])
    pattern = '|'.join(target_muscles)
    df = df[df['muscle_group'].str.contains(pattern, case=False, na=False)].copy()

    df.loc[df['level'].str.contains(target_level, case=False, na=False), 'score'] += 5
    df.loc[df['equipment'].str.contains('barbell|dumbbell', case=False, na=False), 'score'] += 2

    recommended = df.sort_values(by='score', ascending=False)

    final_routine = []
    current_time = 0
    
    grouped_data = {}
    for muscle in target_muscles:
        grouped_data[muscle] = recommended[recommended['muscle_group'].str.contains(muscle, case=False)].to_dict('records')

    while current_time < available_time_mins:
        added_in_round = False
        for muscle in target_muscles:
            if grouped_data[muscle]: 
                ex = grouped_data[muscle].pop(0) 
                
                if current_time + ex['estimated_time_mins'] <= available_time_mins + 3:
                    final_routine.append(ex)
                    current_time += ex['estimated_time_mins']
                    added_in_round = True
                    
        if not added_in_round:
            break

    result_df = pd.DataFrame(final_routine)
    if not result_df.empty:
        return result_df[['name', 'muscle_group', 'equipment', 'level', 'estimated_time_mins', 'score']], current_time
    return pd.DataFrame(), 0

# ==================== KHỐI TEST ====================
if __name__ == "__main__":
    _, gym_data = load_and_preprocess_data()
    if gym_data is not None:
        TIME_LIMIT = 40 
        print(f"\n💪 GỢI Ý BÀI TẬP PUSH - THỜI GIAN: {TIME_LIMIT} PHÚT 💪")
        routine, total_time = recommend_workout_routine(gym_data, "Push", "Beginner", available_time_mins=TIME_LIMIT)
        
        print(f"Tổng thời gian dự kiến: {total_time} phút\n")
        for idx, row in routine.iterrows():
            print(f"- {row['name']} ({row['muscle_group']}) | Dụng cụ: {row['equipment']} | Thời gian: {row['estimated_time_mins']}p")