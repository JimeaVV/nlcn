import os
import tempfile
import unittest

import pandas as pd

from backend.calorie_calculator import calculate_target_calories
from backend.constraint_based import branch_and_bound_meal, generate_meal_plan
from backend.content_based import recommend_workout_routine
from backend.progressive_overload import suggest_progressive_overload
from backend.tienxuly import load_and_preprocess_data


class RecommendationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.food_data, cls.gym_data = load_and_preprocess_data()
        if cls.food_data is None or cls.gym_data is None:
            raise RuntimeError("Test datasets could not be loaded.")

    def test_dataset_paths_do_not_depend_on_working_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            previous = os.getcwd()
            try:
                os.chdir(directory)
                food_data, gym_data = load_and_preprocess_data()
            finally:
                os.chdir(previous)

        self.assertEqual(len(food_data), 160)
        self.assertEqual(len(gym_data), 96)

    def test_calorie_calculation(self):
        self.assertEqual(
            calculate_target_calories(21, "male", 70, 175, 1.55),
            (1694, 2625, 2125),
        )

    def test_calorie_calculation_rejects_unknown_gender(self):
        with self.assertRaises(ValueError):
            calculate_target_calories(21, "unknown", 70, 175, 1.55)

    def test_calorie_calculation_rejects_unsupported_activity_factor(self):
        with self.assertRaises(ValueError):
            calculate_target_calories(21, "male", 70, 175, 9.0)

    def test_meal_plan_contains_three_complete_meals(self):
        plan = generate_meal_plan(
            self.food_data.to_dict("records"),
            daily_calories=2125,
            body_weight_kg=70,
        )
        self.assertEqual(set(plan["meals"]), {"Breakfast", "Lunch", "Dinner"})
        expected_groups = {
            "Breakfast": {"starch", "dairyegg", "fruit"},
            "Lunch": {"starch", "meat", "veggie"},
            "Dinner": {"starch", "meat", "veggie"},
        }
        for meal_name, meal in plan["meals"].items():
            self.assertTrue(meal["items"])
            actual_groups = {item["food_group"] for item in meal["items"]}
            self.assertTrue(expected_groups[meal_name].issubset(actual_groups))
            self.assertLessEqual(meal["calo"], meal["target_calo"] * 1.12)

        lunch = plan["meals"]["Lunch"]["items"]
        dinner = plan["meals"]["Dinner"]["items"]
        for group in ("starch", "meat"):
            lunch_names = {
                item["name"] for item in lunch if item["food_group"] == group
            }
            dinner_names = {
                item["name"] for item in dinner if item["food_group"] == group
            }
            self.assertTrue(lunch_names.isdisjoint(dinner_names))

    def test_seeded_meal_recommendation_is_reproducible(self):
        foods = self.food_data.to_dict("records")
        first = generate_meal_plan(
            foods,
            daily_calories=1700,
            body_weight_kg=60,
            seed=42,
        )
        second = generate_meal_plan(
            foods,
            daily_calories=1700,
            body_weight_kg=60,
            seed=42,
        )

        def selected_items(plan):
            return [
                [item["display_name"] for item in meal["items"]]
                for meal in plan["meals"].values()
            ]

        self.assertEqual(selected_items(first), selected_items(second))
        self.assertEqual(first["total_calo"], second["total_calo"])

    def test_meal_portion_never_exceeds_dataset_maximum(self):
        food = {
            "name": "Concentrated food",
            "macro_group": "meat",
            "calories_per_100g": 100,
            "protein_g": 30,
            "carb_g": 0,
            "fat_g": 0,
            "max_amount_g": 30,
            "suggested_prep": "Serve directly",
        }
        meal = branch_and_bound_meal(
            [("meat", [food], False)],
            target_calories=100,
            target_protein=9,
            time_limit=0.1,
        )
        self.assertEqual(meal["items"][0]["portion_g"], 30)

    def test_workout_respects_exercise_limit(self):
        routine, total_time = recommend_workout_routine(
            self.gym_data,
            "Push",
            "Beginner",
            45,
        )
        self.assertLessEqual(len(routine), 5)
        self.assertGreater(len(routine), 0)
        self.assertLessEqual(total_time, 45)
        self.assertEqual(len(routine["name"].str.casefold().unique()), len(routine))

    def test_workout_prefers_exact_level_over_equipment_bonus(self):
        gym_data = pd.DataFrame(
            [
                {
                    "name": "Exact-level exercise",
                    "muscle_group": "Abdominals",
                    "equipment": "Body Only",
                    "level": "Beginner",
                },
                {
                    "name": "Adjacent-level exercise",
                    "muscle_group": "Abdominals",
                    "equipment": "Barbell",
                    "level": "Intermediate",
                },
            ]
        )
        routine, _ = recommend_workout_routine(
            gym_data,
            "Core",
            "Beginner",
            15,
        )
        self.assertEqual(routine.iloc[0]["name"], "Exact-level exercise")

    def test_workout_tries_a_shorter_candidate_when_top_choice_does_not_fit(self):
        gym_data = pd.DataFrame(
            [
                {
                    "name": "Chest machine",
                    "muscle_group": "Chest",
                    "equipment": "Machine",
                    "level": "Beginner",
                },
                {
                    "name": "Long shoulder exercise",
                    "muscle_group": "Shoulders",
                    "equipment": "Barbell",
                    "level": "Beginner",
                },
                {
                    "name": "Short shoulder exercise",
                    "muscle_group": "Shoulders",
                    "equipment": "Body Only",
                    "level": "Beginner",
                },
            ]
        )
        routine, total_time = recommend_workout_routine(
            gym_data,
            "Push",
            "Beginner",
            17,
        )
        self.assertEqual(total_time, 17)
        self.assertIn("Short shoulder exercise", set(routine["name"]))

    def test_progressive_overload_increases_weight_after_three_by_twelve(self):
        result = suggest_progressive_overload(50, [12, 12, 12], "Moderate")
        self.assertEqual(result["action"], "increase_weight")
        self.assertEqual(result["next_weight"], 52.5)
        self.assertEqual(result["next_rep_target"], 8)

    def test_progressive_overload_covers_maintain_and_decrease_branches(self):
        maintain = suggest_progressive_overload(50, [10, 10, 10], "Moderate")
        hard_twelve = suggest_progressive_overload(50, [12, 12, 12], "Hard")
        decrease = suggest_progressive_overload(50, [7, 8, 8], "Hard")

        self.assertEqual(maintain["action"], "increase_reps")
        self.assertEqual(hard_twelve["action"], "maintain_weight")
        self.assertEqual(decrease["action"], "decrease_weight")
        self.assertEqual(decrease["next_weight"], 47.5)


if __name__ == "__main__":
    unittest.main()
