import mysql.connector
import os

# Database connection settings
# TODO: consider moving these to a config file
DB_HOST = os.environ.get("DB_HOST", "huskyhub-db")
DB_USER = os.environ.get("DB_USER", "user")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "supersecretpw")
DB_NAME = os.environ.get("DB_NAME", "huskyhub")


def get_connection():
    return mysql.connector.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
    )
