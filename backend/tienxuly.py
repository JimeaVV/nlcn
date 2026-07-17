import pandas as pd

def load_and_preprocess_data():
    try:
        food_df = pd.read_csv('data/final-food-dataset.csv')
        gym_df = pd.read_csv('data/gym-ex-dataset.csv')
    except FileNotFoundError:
        return None, None

    ### FOOD ###
    food_df = food_df.dropna()
    food_df = food_df.drop_duplicates(subset=['name'])  
    food_df.columns = food_df.columns.str.strip().str.replace('\n', '').str.replace('\r', '')

    for col in food_df.columns:
        if any(keyword in col for keyword in ['Calorie', 'Protein', 'Carb', 'Fat']):
            food_df[col] = pd.to_numeric(food_df[col], errors='coerce').fillna(0)

    ### GYM EX ###
    gym_df = gym_df.dropna()
    gym_df = gym_df.drop_duplicates()
    gym_df.columns = gym_df.columns.str.strip().str.replace('\n', '').str.replace('\r', '')

    for col in gym_df.columns:
        if 'Muscle' in col:
            gym_df[col] = gym_df[col].astype(str).str.strip()

    return food_df, gym_df

### TEST ###
if __name__ == "__main__":
    food_data, gym_data = load_and_preprocess_data()
    
    if food_data is not None:
        print("Food columns:", list(food_data.columns))
        print("Gym columns:", list(gym_data.columns))
