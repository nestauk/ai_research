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

### Database connection

# set up connection to existing PostgreSQL database, just plug in own details
con <- dbConnect(drv = RPostgres::Postgres(), 
                 dbname = "patentdb",
                 host = "130.225.57.105", port = 5432,
                 user = "patentdbowner", password = "e6rKPT2iZ99@PKaa")

# Inspect DB:
db_list_tables(con) %>% sort()

# set up tables
tbl_mag_papers <- tbl(con, "mag_papers") 
tbl_mag_papers %>% glimpse()

tbl_mag_author_affiliation <- tbl(con, "mag_author_affiliation") 
tbl_mag_author_affiliation %>% head()

tbl_affiliation_type <- tbl(con, "affiliation_type") 
tbl_affiliation_type %>% head()

tbl_mag_affiliation <- tbl(con, "mag_affiliation") 
tbl_mag_affiliation %>% head()

tbl_geocoded_places <- tbl(con, "geocoded_places") 
tbl_geocoded_places %>% glimpse()

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
tbl_author_type %>% saveRDS('../temp.tbl_author_type.rds')


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
tbl_author_year %>% saveRDS('../temp.tbl_author_year.rds')

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


