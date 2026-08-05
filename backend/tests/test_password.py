import sys
import os

sys.path.append(
    os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            ".."
        )
    )
)

from auth.password_handler import verify_password


hash_db = "$2b$12$ev.HfL5wyTnJ/3aT8Olk6eqf4XomntO8VXhlq5BGt/BjXK8ipHTrW"


def test_admin_password_correcta():
    assert verify_password("admin123", hash_db) is True


def test_admin_password_antigua():
    assert verify_password("admin", hash_db) is False