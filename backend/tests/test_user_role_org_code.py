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
        self.session.add(models.Role(role_id=22, role_name="Admin", org_code="NP"))
        self.session.commit()

    def tearDown(self):
        self.session.close()

    def test_create_user_sets_org_code_on_user_role(self):
        payload = UserCreateAdmin(
            first_name="roan",
            last_name="roan",
            middle_name="A",
            suffix="A",
            email="roan@gmail.com",
            contact="09277709812",
            username="roanroan",
            password="roanroan",
            org_code="NP",
            role_ids=[22],
        )

        user = create_user(payload, self.session)
        record = self.session.query(models.UserRole).first()

        self.assertEqual(user.org_code, "NP")
        self.assertIsNotNone(record)
        self.assertEqual(record.org_code, "NP")


if __name__ == "__main__":
    unittest.main()
