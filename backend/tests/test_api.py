import unittest
import warnings

warnings.filterwarnings(
    "ignore",
    message="Using `httpx` with `starlette.testclient` is deprecated.*",
)

from fastapi.testclient import TestClient

from backend.main import app


class ApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client_context = TestClient(app)
        cls.client = cls.client_context.__enter__()

    @classmethod
    def tearDownClass(cls):
        cls.client_context.__exit__(None, None, None)

    def test_health_reports_loaded_datasets(self):
        response = self.client.get("/api/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ok")

    def test_invalid_diet_input_returns_validation_error(self):
        response = self.client.post(
            "/api/recommend-diet",
            json={
                "age": 0,
                "gender": "unknown",
                "weight": 70,
                "height": 175,
                "activity_level": 1.55,
            },
        )
        self.assertEqual(response.status_code, 422)

    def test_diet_endpoint_returns_a_complete_plan(self):
        response = self.client.post(
            "/api/recommend-diet",
            json={
                "age": 21,
                "gender": "male",
                "weight": 70,
                "height": 175,
                "activity_level": 1.55,
            },
        )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["status"], "success")
        self.assertEqual(
            set(body["data"]["meals"]),
            {"Breakfast", "Lunch", "Dinner"},
        )

    def test_invalid_workout_input_returns_validation_error(self):
        response = self.client.post(
            "/api/recommend-workout",
            json={
                "target_split": "Unknown",
                "target_level": "Expert",
                "available_time_mins": -10,
            },
        )
        self.assertEqual(response.status_code, 422)

    def test_workout_endpoint_respects_the_requested_time(self):
        response = self.client.post(
            "/api/recommend-workout",
            json={
                "target_split": "Push",
                "target_level": "Beginner",
                "available_time_mins": 45,
            },
        )
        self.assertEqual(response.status_code, 200)
        body = response.json()
        names = [exercise["name"].casefold() for exercise in body["data"]]
        self.assertLessEqual(body["estimated_time"], 45)
        self.assertEqual(body["total_exercises"], len(body["data"]))
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(body["requested_level"], "Beginner")
        self.assertTrue(body["level_fallback_used"])
        self.assertIn("Intermediate", body["used_levels"])

    def test_progressive_overload_endpoint(self):
        response = self.client.post(
            "/api/progressive-overload",
            json={
                "exercise_name": "Bench Press",
                "current_weight": 50,
                "set_1_reps": 12,
                "set_2_reps": 12,
                "set_3_reps": 12,
                "difficulty": "Moderate",
            },
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["data"]["action"], "increase_weight")


if __name__ == "__main__":
    unittest.main()
