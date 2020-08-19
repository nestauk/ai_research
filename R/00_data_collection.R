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

# set up papeers
tbl(con, "mag_papers") 