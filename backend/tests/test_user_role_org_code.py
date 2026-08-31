import unittest

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from config.database import Base
from models import models
from models.schemas import UserCreateAdmin
from router.users import create_user


class UserRoleOrgCodeTest(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(bind=self.engine)
        self.session = Session(self.engine)
        
        # Create test role
        self.session.add(models.Role(role_id=1, role_name="Admin", org_code="NP"))
        self.session.commit()

    def tearDown(self):
        self.session.close()

    def test_create_user_sets_org_code_from_current_user(self):
        current_user = models.User(
            user_id=1,
            username="admin_np",
            org_code="NP",
            is_active=True,
        )
        
        payload = UserCreateAdmin(
            first_name="roan",
            last_name="roan",
            middle_name="A",
            suffix="A",
            email="roan@gmail.com",
            contact="09277709812",
            username="roanroan",
            password="roanroan",
            role_ids=[1],
        )

        user = create_user(payload, self.session, current_user)
        
        self.assertEqual(user.org_code, "NP")
        record = self.session.query(models.UserRole).first()
        self.assertIsNotNone(record)
        self.assertEqual(record.org_code, "NP")


if __name__ == "__main__":
    unittest.main()