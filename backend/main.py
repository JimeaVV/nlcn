from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import Literal

import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

if __package__:
    from .calorie_calculator import calculate_target_calories
    from .constraint_based import generate_meal_plan
    from .content_based import LEVEL_MAX_EXERCISES, recommend_workout_routine
    from .progressive_overload import suggest_progressive_overload
    from .tienxuly import load_and_preprocess_data
else:
    from calorie_calculator import calculate_target_calories
    from constraint_based import generate_meal_plan
    from content_based import LEVEL_MAX_EXERCISES, recommend_workout_routine
    from progressive_overload import suggest_progressive_overload
    from tienxuly import load_and_preprocess_data

logger = logging.getLogger("optifit.api")

Gender = Literal["male", "female"]
ActivityLevel = Literal[1.2, 1.375, 1.55, 1.725, 1.9]
WorkoutSplit = Literal["Push", "Pull", "Legs", "Core"]
ExperienceLevel = Literal["Beginner", "Intermediate", "Pro"]
Difficulty = Literal["Easy", "Moderate", "Hard", "Failure"]


@asynccontextmanager
async def lifespan(app: FastAPI):
    food_data, gym_data = load_and_preprocess_data()
    app.state.food_data = food_data
    app.state.gym_data = gym_data
    app.state.food_list = (
        food_data.to_dict("records") if food_data is not None else []
    )

    if food_data is None or gym_data is None:
        logger.error("One or more recommendation datasets could not be loaded.")
    else:
        logger.info(
            "Datasets loaded: %s foods and %s exercises.",
            len(food_data),
            len(gym_data),
        )

    yield


app = FastAPI(
    title="OptiFit Recommender API",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class DietRequest(BaseModel):
    age: int = Field(ge=13, le=100)
    gender: Gender
    weight: float = Field(gt=0, le=500)
    height: float = Field(gt=0, le=300)
    activity_level: ActivityLevel


class WorkoutRequest(BaseModel):
    target_split: WorkoutSplit
    target_level: ExperienceLevel
    available_time_mins: int = Field(default=45, ge=15, le=180)


class ProgressiveOverloadRequest(BaseModel):
    exercise_name: str = Field(min_length=1, max_length=200)
    current_weight: float = Field(ge=0, le=1000)
    set_1_reps: int = Field(ge=0, le=30)
    set_2_reps: int = Field(ge=0, le=30)
    set_3_reps: int = Field(ge=0, le=30)
    difficulty: Difficulty


def _workout_note(
    remaining_time: int,
) -> str:
    notes: list[str] = []
    if remaining_time > 0:
        notes.append(
            "Remaining time can be used for warm-up, rest between sets, "
            "cool-down or cardio."
        )
    return " ".join(notes)


@app.get("/api/health")
def health_check(request: Request):
    food_data = request.app.state.food_data
    gym_data = request.app.state.gym_data
    datasets_ready = food_data is not None and gym_data is not None
    return {
        "status": "ok" if datasets_ready else "degraded",
        "food_rows": len(food_data) if food_data is not None else 0,
        "gym_rows": len(gym_data) if gym_data is not None else 0,
    }


@app.post("/api/recommend-diet")
def get_diet_plan(req: DietRequest, request: Request):
    food_list = request.app.state.food_list
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
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Diet recommendation failed.")
        raise HTTPException(
            status_code=500,
            detail="Unable to generate a diet recommendation.",
        ) from exc

    return {
        "status": "success",
        "message": "Successfully recommended diet plan!",
        "bmr": bmr,
        "tdee": tdee,
        "target_calories": target_calories,
        "data": meal_plan,
    }


@app.post("/api/recommend-workout")
def get_workout_plan(req: WorkoutRequest, request: Request):
    gym_data = request.app.state.gym_data
    if gym_data is None:
        raise HTTPException(
            status_code=503,
            detail="Workout dataset is unavailable.",
        )

    try:
        routine_df, total_time = recommend_workout_routine(
            gym_data,
            req.target_split,
            req.target_level,
            req.available_time_mins,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Workout recommendation failed.")
        raise HTTPException(
            status_code=500,
            detail="Unable to generate a workout recommendation.",
        ) from exc

    routine_list = routine_df.to_dict("records")
    remaining_time = max(0, req.available_time_mins - total_time)
    used_levels = sorted({str(item["level"]) for item in routine_list})
    level_fallback_used = any(
        level.casefold() != req.target_level.casefold() for level in used_levels
    )

    return {
        "status": "success",
        "message": "Workout plan generated successfully!",
        "target_time": req.available_time_mins,
        "estimated_time": total_time,
        "remaining_time": remaining_time,
        "total_exercises": len(routine_list),
        "exercise_limit": LEVEL_MAX_EXERCISES[req.target_level],
        "requested_level": req.target_level,
        "used_levels": used_levels,
        "level_fallback_used": level_fallback_used,
        "note": _workout_note(
            remaining_time,
        ),
        "data": routine_list,
    }


@app.post("/api/progressive-overload")
def get_progressive_overload(req: ProgressiveOverloadRequest):
    try:
        recommendation = suggest_progressive_overload(
            current_weight=req.current_weight,
            reps_per_set=[req.set_1_reps, req.set_2_reps, req.set_3_reps],
            difficulty=req.difficulty,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        logger.exception("Progressive Overload recommendation failed.")
        raise HTTPException(
            status_code=500,
            detail="Unable to generate a Progressive Overload recommendation.",
        ) from exc

    return {
        "status": "success",
        "message": "Progressive overload recommendation generated.",
        "exercise_name": req.exercise_name,
        "data": recommendation,
    }


if __name__ == "__main__":
    module = "backend.main:app" if __package__ else "main:app"
    uvicorn.run(module, host="0.0.0.0", port=8000, reload=True)
