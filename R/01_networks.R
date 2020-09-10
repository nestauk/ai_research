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

db_list_tables(con) %>% sort()

### set up tables
# Papers
tbl_mag_papers <- tbl(con, "mag_papers") 
tbl_mag_papers %>% glimpse()

# Authors
tbl_mag_paper_authors <- tbl(con, "mag_paper_authors") 
tbl_mag_paper_authors %>% head()

# Affiliation
tbl_mag_author_affiliation <- tbl(con, "mag_author_affiliation") 
tbl_mag_author_affiliation %>% head()

tbl_affiliation_type <- tbl(con, "affiliation_type") 
tbl_affiliation_type %>% head()

############################################################################
# Network Analysis
############################################################################

# Load packages
library(tidygraph)
library(igraph)

# Load some data in the SQL
readRDS('../temp/tbl_author_year.rds') %>% copy_to(con, df = ., name = 'XTRA_author_type')
tbl_author_year <- tbl(con, "XTRA_author_type") 

el_2m <- tbl_mag_paper_authors %>%select(-order) %>% rename(i = author_id) %>% 
  left_join(tbl_mag_paper_authors %>%select(-order) %>% rename(j = author_id), by = 'paper_id') %>%
  filter(i != j) %>%
  inner_join(tbl_mag_papers %>% select(id, year), by = c('paper_id' = 'id')) %>%
  mutate(year = year %>% as.numeric()) %>%
  inner_join(tbl_author_year %>% select(author_id, year, affiliation) %>% rename(affiliation_i = affiliation), by = c('i' = 'author_id', 'year')) %>%
  inner_join(tbl_author_year %>% select(author_id, year, affiliation) %>% rename(affiliation_j = affiliation), by = c('j' = 'author_id', 'year')) %>%
  compute()

author_cent <- el_2m %>%
  collect() %>%
  group_by(paper_id) %>%
  mutate(weight = 1 / n_distinct(i)) %>%
  ungroup() %>%
  group_by(i, year) %>%
  summarise(cent_dgr = sum(weight),
            cent_dgr_uni = sum(weight * affiliation_j)) %>%
  mutate(cent_dgr_ind = cent_dgr - cent_dgr_uni)

# in between save
author_cent %>% saveRDS('../temp/author_cent.rds')



# TODO:
# MAke tidygraph
# Merge with affilldata 
# Morph to subgraph by year (edges)
# Create EV centrality
# Create EV with industry (figure out how...)



