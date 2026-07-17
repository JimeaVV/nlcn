from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

from tienxuly import load_and_preprocess_data
from constraint_based import generate_meal_plan
from content_based import recommend_workout_routine
from calorie_calculator import calculate_target_calories

app = FastAPI(title="Gym & Diet Recommender API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

print("Loading and preprocessing datasets...")
food_data, gym_data = load_and_preprocess_data()

if food_data is None or gym_data is None:
    print("ERROR: Could not load data. Please check the CSV files!")
    food_list = []
else:
    food_list = food_data.to_dict("records")
    print("Data loaded successfully! Server is ready.")


class DietRequest(BaseModel):
    age: int
    gender: str
    weight: float
    height: float
    activity_level: float


class WorkoutRequest(BaseModel):
    target_split: str
    target_level: str
    available_time_mins: int = 45


@app.get("/api/health")
def health_check():
    return {
        "status": "ok",
        "food_rows": len(food_data) if food_data is not None else 0,
        "gym_rows": len(gym_data) if gym_data is not None else 0,
    }


@app.post("/api/recommend-diet")
def get_diet_plan(req: DietRequest):
    if not food_list:
        raise HTTPException(status_code=503, detail="Food dataset is unavailable.")

    try:
        bmr, tdee, target_calories = calculate_target_calories(
            age=req.age,
            gender=req.gender,
            weight=req.weight,
            height=req.height,
            activity_level=req.activity_level,
        )

        meal_plan = generate_meal_plan(
            food_list=food_list,
            daily_calories=target_calories,
            body_weight_kg=req.weight,
            protein_per_kg=1.8,
        )

        return {
            "status": "success",
            "message": "Successfully recommended diet plan!",
            "bmr": bmr,
            "tdee": tdee,
            "target_calories": target_calories,
            "data": meal_plan,
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.post("/api/recommend-workout")
def get_workout_plan(req: WorkoutRequest):
    if gym_data is None:
        raise HTTPException(status_code=503, detail="Workout dataset is unavailable.")

    try:
        routine_df, total_time = recommend_workout_routine(
            gym_data,
            req.target_split,
            req.target_level,
            req.available_time_mins,
        )

        routine_list = routine_df.to_dict("records")

        return {
            "status": "success",
            "message": "Workout plan generated successfully!",
            "target_time": req.available_time_mins,
            "estimated_time": total_time,
            "total_exercises": len(routine_list),
            "data": routine_list,
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
