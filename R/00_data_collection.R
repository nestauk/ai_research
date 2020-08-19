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

############################################################################
# Merging
############################################################################

tbl_author_paper <- tbl_mag_papers %>% 
  select(id, year) %>%
  rename(paper_id = id) %>%
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
  summarize(n_paper = n(),
            affiliation = type %>% mean() %>% round(0)) %>%
  select(author_id, year, n_paper, affiliation) %>%
  collect() %>%
  mutate(year = year %>% as.numeric()) %>%
  drop_na()

# Fill missing year
tbl_author_year %<>%
  arrange(author_id, year) %>%
  relocate(author_id, year) %>%
  group_by(author_id) %>%
  complete(year = full_seq(min(year):max(year), 1)) %>%
  fill(affiliation, direction ='down') %>%
  ungroup() %>%
  replace_na(list(n_paper = 0))

# in between save
tbl_author_year %>% saveRDS('../temp.tbl_author_year.rds')

### Identify types
tbl_author_type <- tbl_author_year %>%
  group_by(author_id) %>%
  summarize(author_type = case_when(mean(affiliation) == 0 ~ 'industry',
                                 mean(affiliation) > 0 & mean(affiliation) < 1 ~ 'switcher', 
                                 mean(affiliation) == 1 ~ 'academia'),
            n_paper = sum(n_paper),
            year_start = min(year),
            year_end = max(year),
            year_n = n()) 

tbl_author_type %>% count(author_type)

### Identify switches.....
