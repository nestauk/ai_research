"""
Fetches place names from a PostgreSQL DB, queries them to Google Places API to first,
find their Place ID (unique place id given by Google) and second, use the Place ID 
to get the details of the place. The API response is then parsed and stored in a PostgreSQL DB table.

It is first checked if the details of a place have already been collected. If not, its MAG ID and 
name are stored in the `queries` object (sqlalchemy.orm.query.Query) in the form [(123, 'foo'), (234, 'bar')].

Example of a parsed response:
{'lat': 51.504589,
 'lng': -0.09708649999999999,
 'address': '441, Metal Box Factory, 30 Great Guildford St, London SE1 0HS, UK',
 'name': 'Mozilla',
 'id': 'ChIJd7gxxc0EdkgRsxXmeQyR44A',
 'types': ['point_of_interest', 'establishment'],
 'website': 'https://www.mozilla.org/contact/spaces/london/',
 'postal_town': 'London',
 'administrative_area_level_2': 'Greater London',
 'administrative_area_level_1': 'England',
 'country': 'United Kingdom'}

"""
import os
import logging
from dotenv import load_dotenv, find_dotenv
from sqlalchemy import create_engine
from sqlalchemy.sql import exists
from sqlalchemy.orm import sessionmaker
from ai_research.mag.mag_orm import Affiliation, AffiliationLocation
from ai_research.geo.geocode import place_by_id, place_by_name, parse_response

if __name__== '__main__':
    logging.basicConfig(level=logging.INFO)
    load_dotenv(find_dotenv())

    # config = ci_mapping.config["data"][""]
    db_config = os.getenv("postgresdb")
    key = os.getenv("google_key")
    
    engine = create_engine(db_config)
    Session = sessionmaker(engine)
    s = Session()

    # Fetch affiliations that have not been geocoded yet.
    queries = s.query(Affiliation.id, Affiliation.affiliation).filter(
        ~exists().where(Affiliation.id == AffiliationLocation.affiliation_id)
    )
    logging.info(f"Number of queries: {queries.count()}")

    for id, name in queries:
        r = place_by_name(name, key)
        if r is not None:
            response = place_by_id(r, key)
            place_details = parse_response(response)
            place_details.update({"affiliation_id": id})
            s.add(AffiliationLocation(**place_details))
            s.commit()
        else:
            continue
