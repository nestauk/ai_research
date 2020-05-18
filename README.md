The Privatization of AI Research: Causes and Consequences
==============================

We analyze the causes and consequences of the ongoing privatization of AI research, particularly the transition of AI researchers from academia to industry. This is a collaborative work between the [Aalborg University](https://www.en.aau.dk/) and [Nesta](https://www.nesta.org.uk/).

## How to use this repository ##
To rerun the data collection and analysis, create a new Anaconda environment with Python >3.6, run `$ pip install -r requirements.txt` to install the Python packages needed for the project, `$ pip install -e .` to install the `ai_research` repo, get the required API keys and setup PostgreSQL as described [here](/ai_research/README.md). Then, run the following scripts contained in the `ai_research` directory:

1. `$ python mag/mag_orm.py`: Creates a PostgreSQL DB named `ai_research` and the tables needed for this project.
2. `$ python query_fos_mag.py`: Collects data from MAG for sets of Fields of Study.
3. `$ python parse_mag.py`: Parses the MAG responses and stores them in PostgreSQL DB.
4. `$ python geocode_affiliations.py`: Geocodes author affiliations.
5. `$ python collect_fos_level.py`: Collects the level in the MAG hierarchy of the Fields of Study in the DB.

--------

<p><small>Project based on the <a target="_blank" href="https://github.com/nestauk/cookiecutter-data-science-nesta">Nesta cookiecutter data science project template</a>.</small></p>
