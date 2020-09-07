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

# # set up papeers
# tbl(con, "mag_papers") 
# tbl_mag_fields_of_study <- tbl(con, "mag_fields_of_study") 
# tbl_mag_field_of_study_metadata <- tbl(con, "mag_field_of_study_metadata") 

############################################################################
# Network Analysis
############################################################################

# Load packages
library(tidygraph)
library(igraph)

# Load prepared data
tbl_author_type <- readRDS('../temp.tbl_author_type.rds')
tbl_author_year <- readRDS('../temp.tbl_author_year.rds')


# Network
tbl_mag_author_affiliation 
# join with year


