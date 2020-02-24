import pytest
import unittest
import os
from sqlalchemy.orm import sessionmaker
from sqlalchemy import create_engine
from ai_research.data.mag_orm import Base
from dotenv import load_dotenv, find_dotenv

load_dotenv(find_dotenv())


class TestMag(unittest.TestCase):
    """Check that the MAG ORM works as expected"""

    engine = create_engine(os.getenv("test_postgresdb"))
    Session = sessionmaker(engine)

    def setUp(self):
        """Create the temporary table"""
        Base.metadata.create_all(self.engine)

    def tearDown(self):
        """Drop the temporary table"""
        Base.metadata.drop_all(self.engine)

    def test_build(self):
        pass


if __name__ == "__main__":
    unittest.main()
