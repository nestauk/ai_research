"""
Collect the level of every Field of Study. Levels take values from 0-5 where 0 is a broad discipline and 5 a niche domain. 
The script checks which FoS have not been mapped to a level yet and then queries Microsoft Academic Graph to find them.
"""
import os
import logging
from sqlalchemy import create_engine
from sqlalchemy.sql import exists
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv, find_dotenv
import ai_research
from ai_research.mag.mag_orm import FieldOfStudy, FosMetadata
from ai_research.mag.query_mag_composite import query_fields_of_study

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    load_dotenv(find_dotenv())

    # API params
    key = os.getenv("mag_key")
    db_config = os.getenv("postgresdb")

    # Connect to db
    engine = create_engine(db_config)
    Session = sessionmaker(engine)
    s = Session()

    # Keep the FoS IDs that haven't been collected yet
    fields_of_study_ids = [
        id_[0]
        for id_ in s.query(FieldOfStudy.id).filter(
            ~exists().where(FieldOfStudy.id == FosMetadata.id)
        )
    ]
    logging.info(f"Fields of study left: {len(fields_of_study_ids)}")

    # Collect FoS metadata
    fos = query_fields_of_study(key, ids=fields_of_study_ids)

    # Parse api response
    for response in fos:
        s.add(FosMetadata(id=response["id"], level=response["level"]))
        s.commit()
