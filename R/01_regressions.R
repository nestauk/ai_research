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
# Survival analysis
############################################################################

# Load packages
library(survival)
library(survminer)
library(ggfortify)

# Control: 
# TODO: Deep learning dummy -> more likely
# TODO: EV centralityy
# TODO: Previous collaboration industry / Average dist industry......

# Load prepared data
tbl_author_type <- readRDS('../temp.tbl_author_type.rds')
tbl_author_year <- readRDS('../temp.tbl_author_year.rds')

### Filter only for author types interesting here
tbl_author_type %<>%
  filter(author_type %in% c('academia', 'switcher') &
           year_n >= 5 &
           year_end >= 2015) 


### Create main data with restrictions on type
data <- tbl_author_year %>% 
  semi_join(tbl_author_type, by = 'author_id')

### Create some variables
data %<>%
  group_by(author_id) %>%
  mutate(seniority = year - min(year, na.rm = TRUE) + 1,
         cit_n = cit_mean * paper_n,
         cit_n_cum = cit_n %>% cumsum()) %>%
  ungroup()

# # Only 2000 up to transit
# data %<>% 
#   arrange(author_id, year) %>%
#   group_by(author_id) %>%
#   filter(lag(transited) != TRUE) %>%
#   ungroup() %>%
#   select(-switch)




############################################################################
# Propensity Score matching
############################################################################
library(MatchIt)
match_psm <- tbl_author_type %>% 
  mutate(author_type = (author_type %>% factor() %>% as.numeric()) -1 )

match_psm  %<>% matchit(author_type ~ paper_mean + cit_mean + year_n, 
                      data = ., method = "nearest", ratio = 1)
summary(match_psm)

match_psm_out <- match_psm %>% 
  match.data() %>% 
  as_tibble() %>% 
  select(author_id, distance, weights)

############################################################################
# Regression
############################################################################

### Prepare for regression
data_surv <- data %>% 
  semi_join(match_psm_out, by = 'author_id') %>%
  group_by(author_id) %>%
  mutate(cit_n = cit_n %>% lag(1),
         cit_n_cum = cit_n_cum %>% lag(1)) %>%
  ungroup() %>%
  filter(year >= 2000) %>%
  group_by(author_id) %>%
  mutate(time = 1:n()) %>%
  ungroup() %>%
  mutate(year = year %>% factor) %>%
  drop_na()

# Surf object
surv_object <- Surv(time = data_surv$time, event = data_surv$transited)

### First Kaplan-Mayer basic model
fit_km0 <- survfit(surv_object ~ 1,
                   data = data_surv)
fit_km0 %>% summary()
fit_km0 %>% autoplot()

fit_km1 <- survfit(surv_object ~ cit_mean,
                data = data_surv)
fit_km1 %>% summary()
fit_km1 %>% autoplot()

### Fir Cox proportional hazard model
fit1_cox <- coxph(surv_object ~ seniority + cit_mean + paper_n + cit_n_cum , 
                    data = data_surv)
fit1_cox %>% summary()
fit1_cox %>% ggforest(data = data_surv)

############################################################################
# Set up for Survival
############################################################################

# Matching: Use package "Matching"
# GenMatch {Matching}

