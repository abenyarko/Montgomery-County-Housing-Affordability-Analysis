# Phase 1: GitHub Connection Verification
# ----------------------------------------

# 1. Check Git version
system("git --version")

# 2. Check Git status
system("git status")

# 3. Check GitHub remote connection
system("git remote -v")

# 4. Check current Git branch
system("git branch --show-current")

# 5. Check Git user configuration
system("git config --global user.name")
system("git config --global user.email")

# Configure your Git identity
system('git config --global user.name "Anthony Benyarko"')

# Replace the email below with your GitHub email
system('git config --global user.email "abenyarko@gmail.com"')

# Verify configuration
system("git config --global user.name")

system("git config --global user.email")

getwd()

folders <- c(
  "R",
  "data",
  "docs",
  "images"
)

invisible(lapply(
  folders,
  dir.create,
  recursive = TRUE,
  showWarnings = FALSE
))

# Current working directory
getwd()

# Verify project folders
data.frame(
  Folder = folders,
  Exists = dir.exists(folders)
)

# Create a placeholder file in each folder
for (folder in folders) {
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
  
  file.create(file.path(folder, ".gitkeep"))
}

# Verify the files exist
list.files(
  recursive = TRUE,
  all.files = TRUE
)

system("git status")
system("git status")

system("git add R/ data/ images/")

system('git commit -m "Initialize PCC analytics project folder structure"')

system("git push origin main")

# Check whether Git is ignoring the docs folder
system("git check-ignore -v docs/.gitkeep")

# Check current repository status
system("git status")

# Open the existing .gitignore file
file.edit(".gitignore")

# Begin Project here

# --------------------------------------------
# 1. PACKAGE SETUP
# --------------------------------------------

packages <- c(
  "tidyverse",
  "janitor",
  "scales"
)

new_packages <- packages[
  !packages %in% rownames(installed.packages())
]

if (length(new_packages) > 0) {
  install.packages(new_packages)
}

library(tidyverse)
library(janitor)
library(scales)

# -------------------------------------------
# 2. Import Housing Data
# -------------------------------------------

ACS_raw <- read_csv("data/ACSDT5Y2024.B25070-2026-11-10T010748.csv")
View(ACS_raw)

#Review Data
dim(ACS_raw)

names(ACS_raw)

# Explore Data

str(ACS_raw)

summary(ACS_raw)

head(ACS_raw)

# Missing values
colSums(is.na(ACS_raw))

# Inspect first few rows and columns
ACS_raw[1:6, 1:7]

# Review the housing categories
ACS_raw %>%
  select(`Label (Grouping)`) %>%
  print(n = Inf)

# Review geographic column names
names(ACS_raw)[1:12]

# --------------------------------------------
# 3. RESHAPE DATA
# --------------------------------------------

ACS_long <- ACS_raw %>%
  
  # Identify the 11 housing categories
  mutate(
    category = case_when(
      row_number() == 1  ~ "total",
      row_number() == 2  ~ "under_10",
      row_number() == 3  ~ "10_14",
      row_number() == 4  ~ "15_19",
      row_number() == 5  ~ "20_24",
      row_number() == 6  ~ "25_29",
      row_number() == 7  ~ "30_34",
      row_number() == 8  ~ "35_39",
      row_number() == 9  ~ "40_49",
      row_number() == 10 ~ "50_plus",
      row_number() == 11 ~ "not_computed"
    )
  ) %>%
  
  # Remove original category labels
  select(-`Label (Grouping)`) %>%
  
  # Convert estimates and MOEs to the same type
  mutate(
    across(
      -category,
      as.character
    )
  ) %>%
  
  # Reshape geographic columns into rows
  pivot_longer(
    cols = -category,
    names_to = c("geography", "measure"),
    names_sep = "!!",
    values_to = "value"
  ) %>%
  
  # Standardize measurement names and parse values
  mutate(
    measure = recode(
      measure,
      "Estimate" = "estimate",
      "Margin of Error" = "moe"
    ),
    value = readr::parse_number(value)
  ) %>%
  
  # Separate estimates and margins of error
  pivot_wider(
    names_from = measure,
    values_from = value
  )

# --------------------------------------------
# VERIFY THE RESULT
# --------------------------------------------

dim(ACS_long)

glimpse(ACS_long)

head(ACS_long, 10)

view(ACS_long)

str(ACS_long)

# --------------------------------------------
# DATA QUALITY CHECK
# --------------------------------------------

ACS_long %>%
  summarise(
    total_rows = n(),
    unique_geographies = n_distinct(geography),
    missing_estimates = sum(is.na(estimate)),
    missing_moes = sum(is.na(moe)),
    negative_estimates = sum(estimate < 0, na.rm = TRUE)
  )

ACS_long %>%
  count(geography) %>%
  count(n, name = "number_of_geographies")

# --------------------------------------------
# CALCULATE HOUSING BURDEN METRICS
# --------------------------------------------

ACS_housing <- ACS_long %>%
  select(geography, category, estimate) %>%
  pivot_wider(
    names_from = category,
    values_from = estimate
  ) %>%
  mutate(
    geography_type = case_when(
      str_starts(geography, "Census Tract") ~ "Tract",
      geography == "Montgomery County, Maryland" ~ "County",
      geography == "Maryland" ~ "State",
      TRUE ~ "Other"
    ),
    
    eligible_renters = total - not_computed,
    
    severe_burden_count = `50_plus`,
    
    burden_30plus_count =
      `30_34` + `35_39` + `40_49` + `50_plus`,
    
    severe_burden_rate = if_else(
      eligible_renters > 0,
      severe_burden_count / eligible_renters * 100,
      NA_real_
    ),
    
    burden_30plus_rate = if_else(
      eligible_renters > 0,
      burden_30plus_count / eligible_renters * 100,
      NA_real_
    )
  )

# Inspect
glimpse(ACS_housing)

county_summary <- ACS_housing %>%
  filter(geography_type == "County") %>%
  select(
    geography,
    total,
    not_computed,
    eligible_renters,
    severe_burden_count,
    severe_burden_rate,
    burden_30plus_count,
    burden_30plus_rate
  )

print(county_summary, width = Inf)

tract_housing <- ACS_housing %>%
  filter(geography_type == "Tract")

# Number of tracts
nrow(tract_housing)

# Missing and zero-denominator checks
tract_housing %>%
  summarise(
    total_tracts = n(),
    zero_denominators = sum(eligible_renters == 0, na.rm = TRUE),
    missing_rates = sum(is.na(severe_burden_rate)),
    invalid_rates = sum(
      severe_burden_rate < 0 |
        severe_burden_rate > 100,
      na.rm = TRUE
    )
  )


# --------------------------------------------------
# 4. Exploratory Analysis and Statistical Validation
# --------------------------------------------------

# Descriptive Statistics

tract_housing %>%
  summarise(
    total_tracts = n(),
    
    mean_severe_rate = mean(
      severe_burden_rate, na.rm = TRUE
    ),
    
    median_severe_rate = median(
      severe_burden_rate, na.rm = TRUE
    ),
    
    sd_severe_rate = sd(
      severe_burden_rate, na.rm = TRUE
    ),
    
    min_severe_rate = min(
      severe_burden_rate, na.rm = TRUE
    ),
    
    max_severe_rate = max(
      severe_burden_rate, na.rm = TRUE
    )
  )

# Examine Small Denominators

tract_housing %>%
  summarise(
    total_tracts = n(),
    
    under_50 = sum(eligible_renters < 50),
    
    under_100 = sum(eligible_renters < 100),
    
    under_200 = sum(eligible_renters < 200),
    
    median_eligible_renters = median(
      eligible_renters
    )
  )

# Highest Severe Burden Rates

top_rate_tracts <- tract_housing %>%
  arrange(desc(severe_burden_rate)) %>%
  select(
    geography,
    eligible_renters,
    severe_burden_count,
    severe_burden_rate
  ) %>%
  slice_head(n = 10)

print(top_rate_tracts, n = 10, width = Inf)

# Highest Severe Burden Counts

top_count_tracts <- tract_housing %>%
  arrange(desc(severe_burden_count)) %>%
  select(
    geography,
    eligible_renters,
    severe_burden_count,
    severe_burden_rate
  ) %>%
  slice_head(n = 10)

print(top_count_tracts, n = 10, width = Inf)

# Examine ACS Margins of Error

ACS_moe <- ACS_long %>%
  select(geography, category, moe) %>%
  pivot_wider(
    names_from = category,
    values_from = moe,
    names_prefix = "moe_"
  )

# Join MOEs to the tract-level data
tract_housing_moe <- tract_housing %>%
  left_join(
    ACS_moe,
    by = "geography"
  ) %>%
  mutate(
    # Relative MOE for severe burden count
    severe_count_relative_moe = if_else(
      severe_burden_count > 0,
      moe_50_plus / severe_burden_count,
      NA_real_
    ),
    
    # Flag highly uncertain count estimates
    high_uncertainty_count = if_else(
      !is.na(severe_count_relative_moe),
      severe_count_relative_moe >= 0.50,
      NA
    ),
    
    # Small-denominator screening flag
    small_denominator = eligible_renters < 100
  )

# Review overall uncertainty
tract_housing_moe %>%
  summarise(
    total_tracts = n(),
    small_denominator_tracts = sum(
      small_denominator
    ),
    high_uncertainty_tracts = sum(
      high_uncertainty_count,
      na.rm = TRUE
    ),
    missing_relative_moe = sum(
      is.na(severe_count_relative_moe)
    )
  )


#Review Selected Tracts

selected_tracts <- c(
  "7008.12",
  "7032.14",
  "7014.17",
  "7032.13",
  "7015.05",
  "7015.09"
)

tract_housing_moe %>%
  filter(
    str_detect(
      geography,
      paste0(
        "Census Tract (",
        paste(selected_tracts, collapse = "|"),
        ");"
      )
    )
  ) %>%
  select(
    geography,
    eligible_renters,
    severe_burden_count,
    moe_50_plus,
    severe_count_relative_moe,
    severe_burden_rate,
    small_denominator,
    high_uncertainty_count
  ) %>%
  arrange(desc(severe_burden_rate)) %>%
  print(n = Inf, width = Inf)

#Verify ACS Category Totals

ACS_housing %>%
  mutate(
    category_sum =
      under_10 +
      `10_14` +
      `15_19` +
      `20_24` +
      `25_29` +
      `30_34` +
      `35_39` +
      `40_49` +
      `50_plus` +
      not_computed,
    
    difference = total - category_sum
  ) %>%
  summarise(
    geographies_checked = n(),
    exact_matches = sum(difference == 0),
    mismatches = sum(difference != 0),
    maximum_absolute_difference = max(abs(difference))
  )


