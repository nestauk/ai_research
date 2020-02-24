"""
Parses a MAG API response which was stored in a pickle. The parsed response is then stored in a PostgreSQL DB.
"""
import logging
import pickle
import glob
import os
import ai_research
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv, find_dotenv
from ai_research.utils.utils import unique_dicts, unique_dicts_by_value, flatten_lists
from ai_research.mag.parse_mag_data import (
    parse_affiliations,
    parse_authors,
    parse_fos,
    parse_journal,
    parse_papers,
    parse_conference,
)
from ai_research.data.mag_orm import (
    Paper,
    PaperAuthor,
    Journal,
    Author,
    Affiliation,
    FieldOfStudy,
    PaperFieldsOfStudy,
    Conference,
    AuthorAffiliation,
)

if __name__ == "__main__":

    load_dotenv(find_dotenv())

    external_data = (
        f'{ai_research.project_dir}/{ai_research.config["data"]["external"]["path"]}'
    )

    # Connect to postgresql
    engine = create_engine(os.getenv("postgresdb"))
    Session = sessionmaker(bind=engine)
    s = Session()

    data = []
    for filename in glob.iglob("".join([external_data, "*.pickle"])):
        with open(filename, "rb") as h:
            data.extend(pickle.load(h))

    data = [d for d in unique_dicts_by_value(data, "Id")]
    logging.info(f"Number of unique  papers: {len(data)}")

    papers = [parse_papers(response) for response in data]
    logging.info(f"Completed parsing papers: {len(papers)}")

    journals = [
        parse_journal(response, response["Id"])
        for response in data
        if "J" in response.keys()
    ]

    conferences = [
        parse_conference(response, response["Id"])
        for response in data
        if "C" in response.keys()
    ]

    # Parse author information
    items = [parse_authors(response, response["Id"]) for response in data]
    authors = [
        d
        for d in unique_dicts_by_value(flatten_lists([item[0] for item in items]), "id")
    ]
    paper_with_authors = unique_dicts(flatten_lists([item[1] for item in items]))

    # Parse Fields of Study
    items = [
        parse_fos(response, response["Id"])
        for response in data
        if "F" in response.keys()
    ]
    paper_with_fos = unique_dicts(flatten_lists([item[0] for item in items]))
    fields_of_study = [
        d for d in unique_dicts(flatten_lists([item[1] for item in items]))
    ]

    # Parse affiliations
    items = [parse_affiliations(response, response["Id"]) for response in data]
    affiliations = [d for d in unique_dicts(flatten_lists([item[0] for item in items]))]
    paper_author_aff = [
        d for d in unique_dicts(flatten_lists([item[1] for item in items]))
    ]
    logging.info(f"Parsing completed!")

    # Insert dicts into postgresql
    s.bulk_insert_mappings(Paper, papers)
    s.bulk_insert_mappings(Journal, journals)
    s.bulk_insert_mappings(Author, authors)
    s.bulk_insert_mappings(PaperAuthor, paper_with_authors)
    s.bulk_insert_mappings(FieldOfStudy, fields_of_study)
    s.bulk_insert_mappings(PaperFieldsOfStudy, paper_with_fos)
    s.bulk_insert_mappings(Affiliation, affiliations)
    s.bulk_insert_mappings(AuthorAffiliation, paper_author_aff)
    s.bulk_insert_mappings(Conference, conferences)

    s.commit()
    logging.info("Committed to DB")
