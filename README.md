The Privatization of AI Research: Causes and Consequences
==============================

We analyze the causes and consequences of the ongoing privatization of AI research, particularly the transition of AI researchers from academia to industry. This is a collaborative work between the [Aalborg University](https://www.en.aau.dk/) and [Nesta](https://www.nesta.org.uk/).

## How to use the data / repo ##
- Clone the repository with 

`git clone https://github.com/nestauk/ai_research`

- Do `cd ai_research` to change your working directory to the project's repo and run `make create_environment`. This will create a new Anaconda environment and install all the project dependencies. 
- `conda activate ai_research` to activate the newly created anaconda environment.
- In a jupyter notebook, you can do the following to read a data table:

``` python
import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from ai_research.mag.mag_orm import FieldOfStudy

# Read the configuration file and create a session.
db_config = 'postgres+psycopg2://USER:PASSWORD@HOST:5432/DBNAME'
engine = create_engine(db_config)
Session = sessionmaker(engine)
s = Session()

fields_of_study = pd.read_sql(s.query(FieldOfStudy).statement, s.bind)
```

Note: `mag_orm.py` contains the SQLAlchemy mappings (ORMs) used in the database. In the example above, I imported the `FieldOfStudy` ORM which corresponds to `mag_fields_of_study` table in the database. You have to import the ORMs for the tables you want to read!

## Data ##
Sources:
- [Microsoft Academic Graph](https://www.microsoft.com/en-us/research/project/academic-knowledge/)
- [Google Places API](https://developers.google.com/places/web-service/intro)

### Data decisions ###
- Timeframe: 2000-2020
- We collect MAG papers containing one of the following Fields of Study:
  - deep learning
  - machine learning
  - reinforcement learning
- We keep document with and without a DOI

### Making the EDA data

To create the EDA dataset including a fuzzy match between MAG institutes and Nature university rankings:

`python ai_research/make_eda_data.py`

Processed datasets are stored in `data/processed`.


--------

<p><small>Project based on the <a target="_blank" href="https://github.com/nestauk/cookiecutter-data-science-nesta">Nesta cookiecutter data science project template</a>.</small></p>
