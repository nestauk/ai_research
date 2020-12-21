import requests as requests
import re
from zipfile import ZipFile
from io import BytesIO
import os
import logging
import json
import ai_research
import urllib.request
import pandas as pd
from fuzzywuzzy import fuzz, process

project_dir = ai_research.project_dir
_RAW_DATA_PATH = os.path.join(project_dir, "data/raw")
_PROC_DATA_PATH = os.path.join(project_dir, "data/processed")


def fetch_zip(url,name):
    """Fetch and save zip file"""
    name = re.sub(".zip", "", name)
    target = os.path.join(_RAW_DATA_PATH, name)

    if not os.path.exists(target):

        logging.info(f"fetching {name}")
        f = ZipFile(BytesIO(requests.get(url).content))

        logging.info(f"Extracting {name}")
        f.extract(name, path=_RAW_DATA_PATH)

    else:
        logging.info(f"Already fetched {name}")


def fetch_nonzip(url,name):
    """Fetch and save non zip file"""
    target = os.path.join(_RAW_DATA_PATH, name)

    if not os.path.exists(target):
        logging.info(f"fetching {name}")
        urllib.request.urlretrieve(url, filename=target)
    else:
        logging.info(f"Already fetched {name}")


def fetch_data(url):
    """Fetch data for analysis"""
    name = url.split("/")[-1]

    if "zip" in name:
        fetch_zip(url,name)

    else:
        fetch_nonzip(url,name)


def load_transitions(processed=True):
    """Load transition table"""
    if processed is not True:
        transitions = os.path.join(_RAW_DATA_PATH, "tbl_transitions.csv")
        return pd.read_csv(transitions)
    else:
        transitions = os.path.join(_PROC_DATA_PATH, "tbl_transitions.csv")
        return pd.read_csv(transitions)


def load_papers_authors():
    """Load paper - author lookup"""
    ai_papers = os.path.join(_RAW_DATA_PATH, "ai_papers_all.csv")
    return pd.read_csv(ai_papers)


def load_papers_fos():
    """Load paper - fos lookup"""
    papers_fos = os.path.join(_RAW_DATA_PATH, "ai_papers_fos.csv")
    return pd.read_csv(papers_fos)


def load_org_type_lookup():
    """Load org - type lookup"""
    institute_name = os.path.join(_RAW_DATA_PATH, "institute_name_type_lookup.json")
    with open(institute_name, "r") as infile:
        look = json.load(infile)

    look = {re.sub(",", "", k): v for k, v in look.items()}
    return look


def process_transitions(t, org_type_lookup):
    """Process transitions table
    Args:
        t: transition table
        org_type_lookup: lookup between orgs and org types
    """
    t_ = t.copy()

    # Create affiliation type fields
    t_["affil_type_from"], t_["affil_type_to"] = [
        t[var].map(org_type_lookup) for var in ["affil_name_from", "affil_name_to"]
    ]

    t_nonas = t_.dropna(axis=0, subset=["affil_type_from", "affil_type_to"])

    # Create types of transition based on org types
    t_nonas["transition_type"] = [
        f'{r["affil_type_from"]} to {r["affil_type_to"]}'
        for _id, r in t_nonas.iterrows()
    ]
    return t_nonas


def fetch_university_rankings():
    """Fetch Nature university rankings"""
    url = (
        "https://www.natureindex.com/annual-tables/export/2020/institution/academic/all"
    )
    return pd.read_csv(url)


def process_university_rankings(uni_rankings):
    """Process university ranking names"""
    ur = uni_rankings.copy()

    ur["institute_name"] = [x.split("(")[0].lower().strip() for x in ur["Institution"]]

    return ur


def fuzzy_match_unis(uni_r, institutes):
    """Fuzzy matches university rankings with institute names"""

    uni_ranking_mag_lookup = {}

    for n, i in enumerate(uni_r["institute_name"]):

        if n % 20 == 0:
            logging.info(i)
        b = process.extractOne(i, ai_institutions)

        uni_ranking_mag_lookup[i] = b

    return uni_ranking_mag_lookup


def parse_fuzzy(fuzzy_matched, threshold=90):
    """Parses fuzzy matched dict and returns only matches above threshold"""

    parsed = {}

    for k, v in fuzzy_matched.items():
        if v[1] > threshold:
            parsed[k] = v[0]
        else:
            parsed[k] = "No good match"

    return parsed


def load_university_rankings():
    """Loads table with university rankings"""
    f = f"{_RAW_DATA_PATH}/university_rankings.csv"
    return pd.read_csv(f)


def make_university_rankings(ai_institutions, manual_additions):
    """Fetch, parse and fuzzy match university rankings"""
    logging.info("making university rankings")
    uni_rankings = process_university_rankings(fetch_university_rankings())

    matched = fuzzy_match_unis(uni_rankings, ai_institutions)

    matched_parsed = parse_fuzzy(matched)

    for k, v in manual_additions.items():
        matched_parsed[k] = v

    uni_rankings["institute_mag"] = uni_rankings["institute_name"].map(matched_parsed)

    uni_rankings.to_csv(f"{_PROC_DATA_PATH}/university_rankings.csv", index=False)


if __name__ == "__main__":

    urls = [
        "https://privatisation-ai-researchers.s3.eu-west-2.amazonaws.com/institute_name_type_lookup.json",
        "https://privatisation-ai-researchers.s3.eu-west-2.amazonaws.com/tbl_transitions.csv",
        "https://privatisation-ai-researchers.s3.eu-west-2.amazonaws.com/ai_papers_all.csv.zip",
        "https://privatisation-ai-researchers.s3.eu-west-2.amazonaws.com/ai_papers_fos.csv.zip",
    ]

    for u in urls:
        fetch_data(u)

    logging.info("Processing transition data")

    ol = load_org_type_lookup()
    t = load_transitions(processed=False)
    p = process_transitions(t, ol)
    p.to_csv(f"{_PROC_DATA_PATH}/tbl_transitions.csv")
    ai_institutions = list(set(p["affil_name_from"]) & set(p["affil_name_to"]))

    manual_fixes = {
        "swiss federal institute of technology zurich": "eth zurich",
        "university of chinese academy of sciences": "chinese academy of sciences",
    }

    make_university_rankings(ai_institutions, manual_fixes)
