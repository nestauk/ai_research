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

### Load instiitutional data
tbl_affiliation_dyn <- readRDS('../temp/tbl_institutions_main_indicators.rds')
# TODO: Do something with it

### Load author data

## Author static
tbl_author_stat <- readRDS('../temp/tbl_author_type.rds')

tbl_author_stat %<>%
  replace_na(list(gender = 'male'))

tbl_author_stat %<>%
  mutate(gender = ifelse(gender == 'male', TRUE, FALSE))

# Filter only for author types interesting here
tbl_author_stat %<>%
  filter(author_type %in% c('academia', 'switcher') &
           year_n >= 5 &
           year_end >= 2015) 

# additional data
tbl_author_stat %<>% 
  left_join(tbl(con, "author_gender") %>% select(id, full_name, gender), by = c('author_id' = 'id'), copy = TRUE)

### Load dynamic data
tbl_author_dyn <- readRDS('../temp/tbl_author_year.rds')

# adittional data

tbl_author_dyn %<>%
  left_join(readRDS('../temp/author_cent.rds') %>% select(i, year, cent_dgr, cent_dgr_ind) %>% mutate(year = year %>% as.numeric()), 
            by = c('author_id' = 'i', 'year')) %>%
  left_join(readRDS('../temp/tbl_author_field.rds') %>% mutate(year = year %>% as.numeric()) %>% rename(field_n = n),  
            by = c('author_id', 'year')) %>%
  left_join(readRDS('../temp/dl_authors.rds') %>% select(author_id, year, n, dl_researcher) %>% mutate(year = year %>% as.numeric())  %>% rename(dl_n = n), 
            by = c('author_id', 'year'))

# deal with NAs
tbl_author_dyn %<>%
  replace_na(list(cent_dgr = 0, cent_dgr_ind = 0, field_of_study_id = 0, field_of_study_name = 'none', field_n = 0, dl_n = 0, dl_researcher = FALSE))

# create some variables
tbl_author_dyn %<>%
  mutate(citation_rank = cit_mean %>% percent_rank())

### Create main data with restrictions on type
data <- tbl_author_dyn %>% 
  inner_join(tbl_author_stat %>% select(-paper_mean, -cit_mean), by = 'author_id')

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
match_psm <- tbl_author_stat %>% 
  mutate(author_type = (author_type %>% factor() %>% as.numeric()) -1 ) %>%
  drop_na()

match_psm %>% skimr::skim()

match_psm  %<>% matchit(author_type ~ paper_mean + cit_mean + year_n + gender, 
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
  mutate(cit_n_cum = cit_n_cum %>% lag(1),
         citation_rank = citation_rank %>% lag(1),
         cent_dgr = cent_dgr %>% lag(1),
         cent_dgr_ind = cent_dgr %>% lag(1),
         dl_researcher = dl_researcher %>% lag(1)) %>%
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

fit_km1 <- survfit(surv_object ~ dl_researcher,
                data = data_surv)
fit_km1 %>% summary()
fit_km1 %>% autoplot()

### Fir Cox proportional hazard model
fit1_cox <- coxph(surv_object ~ dl_researcher + cent_dgr + cent_dgr_ind + citation_rank + cit_n_cum + paper_n + seniority + gender,
                    data = data_surv)
fit1_cox %>% summary()
fit1_cox %>% ggforest(data = data_surv)

library(stargazer)
fit1_cox %>% stargazer()

  
############################################################################
# Set up for diff-in-diff
############################################################################

# Matching: Use package "Matching"
# GenMatch {Matching}

