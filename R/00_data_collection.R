############################################################################
# Preamble
############################################################################
rm(list=ls())

### Load packages
library(tidyverse)
library(magrittr)

library(DBI) # GEneral R database interface
library(RPostgres) # PostgreSQL interface driver
library(dbplyr) # for dplyr with databases

### Define functions

slice.tbl_sql <- function(.data, ...) {
  rows <- c(...)
  
  .data %>%
    mutate(...row_id = row_number()) %>%
    filter(...row_id %in% !!rows) %>%
    select(-...row_id)
}


### Database connection

# set up connection to existing PostgreSQL database, just plug in own details
con <- dbConnect(drv = RPostgres::Postgres(), 
                 dbname = "patentdb",
                 host = "130.225.57.105", port = 5432,
                 user = "patentdbowner", password = "e6rKPT2iZ99@PKaa")

# Inspect DB:
db_list_tables(con) %>% sort()

### set up tables
# Papers
tbl_mag_papers <- tbl(con, "mag_papers") 
tbl_mag_papers %>% glimpse()

# Authors
tbl_mag_authors <- tbl(con, "mag_authors") 
tbl_mag_authors %>% head()

tbl_mag_paper_authors <- tbl(con, "mag_paper_authors") 
tbl_mag_paper_authors %>% head()

tbl_author_gender <- tbl(con, "author_gender") 
tbl_author_gender %>% head()

# Affiliation
tbl_mag_author_affiliation <- tbl(con, "mag_author_affiliation") 
tbl_mag_author_affiliation %>% head()

tbl_affiliation_type <- tbl(con, "affiliation_type") 
tbl_affiliation_type %>% head()

tbl_mag_affiliation <- tbl(con, "mag_affiliation") 
tbl_mag_affiliation %>% head()

tbl_geocoded_places <- tbl(con, "geocoded_places") 
tbl_geocoded_places %>% glimpse()

# Field of study
tbl_mag_fields_of_study <- tbl(con, "mag_fields_of_study") 
tbl_mag_fields_of_study %>% glimpse()

tbl_mag_paper_fields_of_study <- tbl(con, "mag_paper_fields_of_study") 
tbl_mag_paper_fields_of_study %>% glimpse()

tbl_mag_field_of_study_metadata <- tbl(con, "mag_field_of_study_metadata") 
tbl_mag_field_of_study_metadata %>% glimpse()

############################################################################
# Merging
############################################################################

tbl_author_paper <- tbl_mag_papers %>% 
  select(id, year, citations) %>%
  rename(paper_id = id) %>%
  mutate(year = year %>% as.numeric(),
         citations = as.numeric(citations) / (2021 - year) ) %>%
  inner_join(tbl_mag_author_affiliation %>% select(paper_id, author_id, affiliation_id), by = 'paper_id') %>%
  inner_join(tbl_affiliation_type, by = c('affiliation_id' = 'id')) %>%
  compute()

###
# TODO: Some preselection??????
###

############################################################################
# Year aggregation author
############################################################################

# Generate
tbl_author_year <- tbl_author_paper %>%
  group_by(year, author_id) %>%
  summarize(paper_n = n() %>% as.integer(),
            cit_mean = citations %>% mean(na.rm = TRUE) %>% round(2),
            affiliation = type %>% mean(na.rm = TRUE) %>% round(0)) %>%
  select(author_id, year, paper_n, cit_mean, affiliation) %>%
  collect() %>%
  drop_na(author_id, year, cit_mean, affiliation)

# Fill missing year
tbl_author_year %<>%
  arrange(author_id, year) %>%
  relocate(author_id, year) %>%
  group_by(author_id) %>%
  complete(year = full_seq(min(year):max(year), 1)) %>%
  fill(affiliation) %>%
  ungroup() %>%
  replace_na(list(paper_n = 0, cit_mean = 0))

###
# TODO Find multipe switchers
###

### Identify types
tbl_author_type <- tbl_author_year %>%
  group_by(author_id) %>%
  summarize(affil_mean = affiliation %>% mean(na.rm = TRUE),
            paper_mean = paper_n %>% mean(na.rm = TRUE),
            cit_mean = cit_mean %>% mean(na.rm = TRUE),
            year_start = min(year),
            year_end = max(year),
            ) %>%
  mutate(author_type = case_when(affil_mean == 0 ~ 'industry',
                                 affil_mean > 0 & affil_mean < 1 ~ 'switcher', 
                                 affil_mean == 1 ~ 'academia',
                                 TRUE ~ 'others'), 
         year_n = year_end - year_start + 1) %>%
  select(author_id, author_type, paper_mean, cit_mean, year_start, year_end, year_n)

# in between save
tbl_author_type %>% saveRDS('../temp/tbl_author_type.rds')


### Identify switches.....

# Join the type back
tbl_author_year %<>%
  left_join(tbl_author_type %>% select(author_id, author_type), by = 'author_id')

# Find switching point
tbl_author_year %<>%
  group_by(author_id) %>%
  mutate(transited = ifelse(affiliation != lead(affiliation, 1) & 
                              affiliation != lead(affiliation, 1), TRUE, NA)) %>%
  fill(transited, .direction = 'down') %>%
  replace_na(list(transited = FALSE)) %>%
  mutate(switch = ifelse(transited == TRUE & lag(transited, 1) == FALSE, TRUE, FALSE))  %>%
  replace_na(list(switch = FALSE)) %>%
  ungroup()

# in between save
tbl_author_year %>% saveRDS('../temp/tbl_author_year.rds')

### Check descriptives

# author level
tbl_author_type %>%
  select(-author_id, -year_start, -year_end) %>%
  group_by(author_type) %>%
  summarise_all(mean)

# before vs later switch
tbl_author_year %>%
  filter(author_type == 'switcher') %>%
  select(transited, paper_n, cit_mean) %>%
  group_by(transited) %>%
  summarise_all(mean)


############################################################################
# AI
############################################################################

# Identify DL papers
dl <- tbl_mag_fields_of_study %>%
  collect() %>%
  filter(name %>% str_detect(fixed('deep learning', ignore_case=TRUE))) %>%
  pull(id)

tbl_dl_fields <- tbl_mag_paper_fields_of_study %>%
  semi_join(tbl_mag_paper_fields_of_study %>% filter(field_of_study_id == dl), by = 'paper_id') %>%
  left_join(tbl_mag_fields_of_study, by = c('field_of_study_id' = 'id')) %>%
  left_join(tbl_mag_field_of_study_metadata %>% select(id, level), by = c('field_of_study_id' = 'id')) %>%
  filter(level >= 3) %>%
  count(field_of_study_id, name, sort = TRUE) %>%
  head(8) %>%
  compute()

dl_papers <- tbl_mag_paper_fields_of_study %>%
  semi_join(tbl_dl_fields, by = 'field_of_study_id')) %>%
  distinct(paper_id) %>%
  compute()

# In between save
x <- dl_papers %>% collect(); x %>% saveRDS('../temp/dl_papers.rds'); rm(x)

### identify DL researcher
dl_authors <- tbl_mag_paper_authors %>%
  semi_join(dl_papers, by = 'paper_id') %>%
  left_join(tbl_mag_papers %>% select(id, year), by = c('paper_id' = 'id')) %>%
  count(author_id, year, sort = TRUE) %>% 
  left_join(tbl_mag_authors, by = c('author_id' = 'id')) %>%
  mutate(dl_researcher = TRUE) %>%
  compute()

# In between save
x <- dl_authors %>% collect(); x %>% saveRDS('../temp/dl_authors.rds'); rm(x)

### Identify DL institutions
dl_institutions <- tbl_mag_author_affiliation %>%
  select(affiliation_id, paper_id) %>%
  semi_join(dl_papers, by = 'paper_id') %>%
  left_join(tbl_mag_papers %>% select(id, year), by = c('paper_id' = 'id')) %>%
  count(affiliation_id, year, sort = TRUE) %>% 
  left_join(tbl_mag_affiliation, by = c('affiliation_id' = 'id')) %>%
  mutate(dl_institution = TRUE) %>%
  compute()

# In between save
x <- dl_institutions %>% collect() %>% drop_na(); x %>% saveRDS('../temp/dl_institutions.rds'); rm(x)

############################################################################
# Field of study
############################################################################

# Papers
tbl_paper_main_indicators <- tbl_mag_paper_fields_of_study %>%
  left_join(tbl_mag_fields_of_study, by = c('field_of_study_id' = 'id')) %>%
  left_join(tbl_mag_field_of_study_metadata, by = c('field_of_study_id' = 'id')) %>%
  left_join(tbl_mag_papers %>% select(id, year, citations), by = c('paper_id' = 'id'))  %>%
  mutate(level = ifelse(level < 3, 4, level)) %>%
  arrange(paper_id, level, desc(frequency)) %>%
  group_by(paper_id) %>%
    slice.tbl_sql(1:1) %>%
  ungroup() %>%
  rename(field_of_study_name = name) %>%
  mutate(citations_rank = citations %>% percent_rank()) %>%
  select(paper_id, year, citations, citations_rank, everything()) %>%
  compute()

tbl_paper_main_fields %>% 
  count(name, sort= TRUE)

### Institutions
tbl_institutions_field <- tbl_paper_main_indicators %>%
  inner_join(tbl_mag_author_affiliation %>% select(affiliation_id, paper_id) %>% filter(affiliation_id >=1), by = 'paper_id') %>%
  count(affiliation_id, year, field_of_study_id, field_of_study_name, sort = TRUE) %>%
  group_by(affiliation_id, year) %>%
    slice.tbl_sql(1:1) %>%
  ungroup() %>%
  compute() 

tbl_institutions_main_indicators <- tbl_paper_main_indicators %>%
  left_join(tbl_mag_author_affiliation %>% select(affiliation_id, paper_id), by = 'paper_id') %>%
  group_by(affiliation_id, year) %>%
    summarise(paper_n = n() %>% as.integer(),
              citation_rank_mean = citations_rank %>% mean(),
              citation_rank_max = citations_rank %>% max()) %>%
  ungroup() %>% 
  left_join(tbl_institutions_field, by = c('affiliation_id', 'year')) %>%
  rename(field_n = n) %>%
  left_join(tbl_mag_affiliation, by = c('affiliation_id' = 'id') ) %>%
  rename(affiliation_name = affiliation) %>%
  compute()

### In between save
x <- tbl_institutions_main_indicators %>% collect() %>% drop_na(); x %>% saveRDS('../temp/tbl_institutions_main_indicators.rds'); rm(x)


# Authors 
tbl_author_field <- tbl_paper_main_indicators %>%
  inner_join(tbl_mag_paper_authors %>% select(author_id, paper_id) %>% filter(author_id >=1), by = 'paper_id') %>%
  count(author_id, year, field_of_study_id, field_of_study_name, sort = TRUE) %>%
  group_by(author_id, year) %>%
  slice.tbl_sql(1:1) %>%
  ungroup() %>%
  compute() 

# In between save
x <- tbl_author_field %>% collect() %>% drop_na(); x %>% saveRDS('../temp/tbl_author_field.rds'); rm(x)




############################################################################
# Consolidate
############################################################################

# Author Dynamic

tbl_author_dyn <- readRDS('../temp/tbl_author_year.rds')

tbl_author_dyn %<>%
  left_join(readRDS('../temp/author_cent.rds') %>% select(i, year, cent_dgr, cent_dgr_ind) %>% mutate(year = year %>% as.numeric()), 
            by = c('author_id' = 'i', 'year')) %>%
  left_join(readRDS('../temp/tbl_author_field.rds') %>% mutate(year = year %>% as.numeric()) %>% rename(field_n = n),  
            by = c('author_id', 'year')) %>%
  left_join(readRDS('../temp/dl_authors.rds') %>% select(author_id, year, n, dl_researcher) %>% mutate(year = year %>% as.numeric())  %>% rename(dl_n = n), 
            by = c('author_id', 'year'))

tbl_author_dyn %>% saveRDS('../temp/tbl_author_dyn_all.rds')

############################################################################
# PSM
############################################################################
