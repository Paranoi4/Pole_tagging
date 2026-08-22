import os
from dotenv import load_dotenv

load_dotenv()

# JWT Configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-here-change-in-production")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 30))
ACCESS_TOKEN_EXPIRE_SECONDS = int(
	os.getenv("ACCESS_TOKEN_EXPIRE_SECONDS", ACCESS_TOKEN_EXPIRE_MINUTES * 60)
)