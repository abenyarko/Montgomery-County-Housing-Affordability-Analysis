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

#  RATE VS COUNT COMPARISON


county_rate <- county_summary$severe_burden_rate[1]

median_count <- median(
  tract_housing_moe$severe_burden_count,
  na.rm = TRUE
)

tract_comparison <- tract_housing_moe %>%
  mutate(
    above_county_rate =
      severe_burden_rate > county_rate,
    
    above_median_count =
      severe_burden_count > median_count,
    
    priority_group = case_when(
      above_county_rate & above_median_count ~
        "High rate / High count",
      
      above_county_rate & !above_median_count ~
        "High rate / Low count",
      
      !above_county_rate & above_median_count ~
        "Low rate / High count",
      
      TRUE ~
        "Low rate / Low count"
    )
  )

# Number of tracts in each group
tract_comparison %>%
  count(priority_group) %>%
  arrange(desc(n))

# Review the median count benchmark
median_count

county_rate <- county_summary$severe_burden_rate[1]

median_count <- median(
  tract_housing_moe$severe_burden_count,
  na.rm = TRUE
)

# --------------------------------------------
# 16.2 UPDATE CLASSIFICATION LABELS
# --------------------------------------------

tract_comparison <- tract_housing_moe %>%
  mutate(
    priority_group = case_when(
      severe_burden_rate > county_rate &
        severe_burden_count > median_count ~
        "Above County Rate / Above Median Count",
      
      severe_burden_rate > county_rate &
        severe_burden_count <= median_count ~
        "Above County Rate / Below Median Count",
      
      severe_burden_rate <= county_rate &
        severe_burden_count > median_count ~
        "Below County Rate / Above Median Count",
      
      TRUE ~
        "Below County Rate / Below Median Count"
    )
  )

# Set legend order
tract_comparison <- tract_comparison %>%
  mutate(
    priority_group = factor(
      priority_group,
      levels = c(
        "Above County Rate / Above Median Count",
        "Above County Rate / Below Median Count",
        "Below County Rate / Above Median Count",
        "Below County Rate / Below Median Count"
      )
    )
  )

# --------------------------------------------
# 16.3 CREATE FINAL SCATTERPLOT
# --------------------------------------------

housing_plot_final <- ggplot(
  tract_comparison,
  aes(
    x = severe_burden_rate,
    y = severe_burden_count,
    color = priority_group
  )
) +
  
  geom_point(
    size = 3,
    alpha = 0.90
  ) +
  
  # Countywide rate benchmark
  geom_vline(
    xintercept = county_rate,
    linetype = "dashed",
    color = "#222222",
    linewidth = 0.7
  ) +
  
  # Median tract count benchmark
  geom_hline(
    yintercept = median_count,
    linetype = "dashed",
    color = "#222222",
    linewidth = 0.7
  ) +
  
  # Bold, contrasting colors
  scale_color_manual(
    values = c(
      "Above County Rate / Above Median Count" = "#007F5F",
      "Above County Rate / Below Median Count" = "#2563EB",
      "Below County Rate / Above Median Count" = "#EA580C",
      "Below County Rate / Below Median Count" = "#7C3AED"
    )
  ) +
  
  # Axis formatting
  scale_x_continuous(
    breaks = seq(0, 100, 20),
    labels = label_percent(scale = 1),
    limits = c(0, 100),
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  
  scale_y_continuous(
    labels = label_comma(),
    expand = expansion(mult = c(0.02, 0.08))
  ) +
  
  # Titles and labels
  labs(
    title = "Housing Burden Rates and Counts Tell Different Stories",
    
    subtitle = paste(
      "232 Montgomery County census tracts |",
      "ACS 2020–2024"
    ),
    
    x = "Severely rent-burdened households (%)",
    
    y = "Estimated severely burdened renter households",
    
    color = NULL,
    
    caption = paste0(
      "Source: U.S. Census Bureau, ACS 2020–2024, Table B25070.\n",
      "Dashed lines: County rate (",
      round(county_rate, 1),
      "%) and median tract count (",
      median_count,
      ").\n",
      "Tract estimates are subject to sampling uncertainty."
    )
  ) +
  
  # Two-row legend
  guides(
    color = guide_legend(
      nrow = 2,
      byrow = TRUE,
      override.aes = list(
        size = 4,
        alpha = 1
      )
    )
  ) +
  
  # Professional theme
  theme_minimal(base_size = 12) +
  
  theme(
    plot.title = element_text(
      face = "bold",
      size = 16,
      color = "#111827"
    ),
    
    plot.subtitle = element_text(
      size = 11,
      color = "#374151",
      margin = margin(b = 12)
    ),
    
    axis.title = element_text(
      face = "bold",
      size = 11,
      color = "#111827"
    ),
    
    axis.text = element_text(
      size = 10,
      color = "#374151"
    ),
    
    panel.grid.minor = element_blank(),
    
    panel.grid.major = element_line(
      color = "#E5E7EB",
      linewidth = 0.3
    ),
    
    legend.position = "bottom",
    
    legend.text = element_text(
      size = 9,
      color = "#111827"
    ),
    
    legend.margin = margin(t = 10),
    
    plot.caption = element_text(
      size = 9,
      color = "#4B5563",
      hjust = 0,
      lineheight = 1.2,
      margin = margin(t = 15)
    ),
    
    plot.margin = margin(
      t = 20,
      r = 25,
      b = 20,
      l = 20
    )
  )

# --------------------------------------------
# 16.4 DISPLAY GRAPH
# --------------------------------------------

print(housing_plot_final)

# --------------------------------------------
# 16.5 EXPORT GRAPH
# --------------------------------------------

ggsave(
  filename = "images/housing_burden_scatterplot_final.png",
  plot = housing_plot_final,
  width = 12,
  height = 9,
  dpi = 300,
  bg = "white"
)

ggsave(
  filename = "images/housing_burden_scatterplot_final.pdf",
  plot = housing_plot_final,
  width = 12,
  height = 7,
  bg = "white"
)

# Additional Visualization

install.packages(c("sf", "tigris", "ggplot2", "tidycensus"))

library(tidycensus)
library(sf)
library(tigris)
library(tidyverse)
library(ggplot2)
library(scales)

options(tigris_use_cache = TRUE)

census_api_key(
  "7a6ac1b8913152d11d6c25b3aef7dedafef6271e",
  install = TRUE,
  overwrite = TRUE
)

# Confirm the key is available without displaying it
nzchar(Sys.getenv("census_api_key"))

ACS_housing_geo <- get_acs(
  geography = "tract",
  variables = c(
    total = "B25070_001",
    severe = "B25070_010",
    not_computed = "B25070_011"
  ),
  state = "MD",
  county = "Montgomery",
  year = 2024,
  survey = "acs5",
  output = "wide",
  geometry = TRUE,
  cache_table = TRUE
)

# Inspect the data
glimpse(ACS_housing_geo)

# Check the number of tracts
nrow(ACS_housing_geo)

# Review geographic identifiers
ACS_housing_geo %>%
  st_drop_geometry() %>%
  select(
    GEOID,
    NAME,
    totalE,
    severeE,
    not_computedE
  ) %>%
  head(10)

# --------------------------------------------
# 17.2 CALCULATE SEVERE HOUSING COST BURDEN
# --------------------------------------------

ACS_housing_geo <- ACS_housing_geo %>%
  mutate(
    eligible_renters = totalE - not_computedE,
    
    severe_burden_count = severeE,
    
    severe_burden_rate = if_else(
      eligible_renters > 0,
      (severe_burden_count / eligible_renters) * 100,
      NA_real_
    )
  )

# Validate calculations
ACS_housing_geo %>%
  st_drop_geometry() %>%
  summarise(
    total_tracts = n(),
    missing_rates = sum(is.na(severe_burden_rate)),
    invalid_rates = sum(
      severe_burden_rate < 0 |
        severe_burden_rate > 100,
      na.rm = TRUE
    ),
    total_severe_households = sum(severe_burden_count)
  )

# --------------------------------------------
# 17.3 VALIDATE AGAINST ORIGINAL DATA
# --------------------------------------------

original_tracts <- tract_housing %>%
  mutate(
    tract_number = stringr::str_extract(
      geography,
      "(?<=Census Tract )[0-9.]+"
    ),
    GEOID = paste0(
      "24031",
      sprintf(
        "%06d",
        round(as.numeric(tract_number) * 100)
      )
    )
  ) %>%
  select(
    GEOID,
    original_count = severe_burden_count,
    original_rate = severe_burden_rate
  )

validation <- ACS_housing_geo %>%
  st_drop_geometry() %>%
  left_join(original_tracts, by = "GEOID") %>%
  mutate(
    count_difference = severe_burden_count - original_count,
    rate_difference = severe_burden_rate - original_rate
  )

validation %>%
  summarise(
    total_tracts = n(),
    matched_tracts = sum(!is.na(original_count)),
    unmatched_tracts = sum(is.na(original_count)),
    max_count_difference = max(
      abs(count_difference),
      na.rm = TRUE
    ),
    max_rate_difference = max(
      abs(rate_difference),
      na.rm = TRUE
    )
  )

# --------------------------------------------
# 17.4 CLASSIFY SEVERE HOUSING BURDEN RATES
# --------------------------------------------

library(dplyr)
library(ggplot2)
library(sf)

ACS_housing_geo <- ACS_housing_geo %>%
  mutate(
    burden_category = case_when(
      severe_burden_rate < 15 ~ "Below 15%",
      
      severe_burden_rate < 25.2 ~ "15% to <25.2%",
      
      severe_burden_rate < 40 ~ "25.2% to <40%",
      
      severe_burden_rate < 60 ~ "40% to <60%",
      
      severe_burden_rate >= 60 ~ "60% or higher",
      
      TRUE ~ NA_character_
    ),
    
    burden_category = factor(
      burden_category,
      levels = c(
        "Below 15%",
        "15% to <25.2%",
        "25.2% to <40%",
        "40% to <60%",
        "60% or higher"
      )
    )
  )

# Check the number of census tracts in each category
ACS_housing_geo %>%
  st_drop_geometry() %>%
  count(burden_category) %>%
  mutate(
    percentage = round(n / sum(n) * 100, 1)
  )

housing_category_summary <- ACS_housing_geo %>%
  sf::st_drop_geometry() %>%
  group_by(burden_category) %>%
  summarise(
    census_tracts = n(),
    eligible_renters = sum(eligible_renters),
    severe_households = sum(severe_burden_count),
    .groups = "drop"
  ) %>%
  mutate(
    pct_of_tracts = round(
      census_tracts / sum(census_tracts) * 100,
      1
    ),
    pct_of_severe_households = round(
      severe_households / sum(severe_households) * 100,
      1
    )
  )

print(housing_category_summary)

burden_colors <- c(
  "Below 15%" = "#DBEAFE",
  "15% to <25.2%" = "#93C5FD",
  "25.2% to <40%" = "#3B82F6",
  "40% to <60%" = "#1D4ED8",
  "60% or higher" = "#172554"
)

# --------------------------------------------
# 17.6 CREATE CATEGORIZED CHOROPLETH MAP
# --------------------------------------------

housing_map_categorical <- ggplot(ACS_housing_geo) +
  
  geom_sf(
    aes(fill = burden_category),
    color = "white",
    linewidth = 0.12
  ) +
  
  scale_fill_manual(
    values = burden_colors,
    drop = FALSE,
    na.value = "#D1D5DB",
    name = "Severe rental burden (%)"
  ) +
  
  labs(
    title = "Geographic Variation in Severe Rental Housing Cost Burden",
    
    subtitle = paste(
      "Montgomery County census tracts |",
      "ACS 2020–2024\n",
      "Percentage of eligible renter households spending 50% or more of income on gross rent."
    ),
    
    caption = paste0(
      "Source: U.S. Census Bureau, ACS 2020–2024, Table B25070.\n",
      "Severe burden: 50% or more of household income spent on gross rent.\n",
      "Countywide rate: 25.2%. Categories are descriptive; ",
      "tract estimates are subject to sampling uncertainty."
    )
  ) +
  
  theme_void() +
  
  theme(
    plot.title = element_text(
      face = "bold",
      size = 15,
      color = "#111827"
    ),
    
    plot.subtitle = element_text(
      size = 10,
      color = "#4B5563",
      lineheight = 1.2,
      margin = margin(b = 12)
    ),
    
    legend.position = "right",
    
    legend.title = element_text(
      face = "bold",
      size = 10
    ),
    
    legend.text = element_text(
      size = 9
    ),
    
    legend.key.height = grid::unit(0.55, "cm"),
    
    legend.key.width = grid::unit(0.55, "cm"),
    
    plot.caption = element_text(
      size = 10,
      hjust = 0,
      margin = margin(t = 12)
    ),
    
    plot.margin = margin(15, 20, 15, 20)
  )

# Display map
print(housing_map_categorical)
----------------------------

  # --------------------------------------------
# 17.7 EXPORT CATEGORIZED MAP
# --------------------------------------------

ggsave(
  filename = "images/montgomery_housing_burden_categorical.png",
  plot = housing_map_categorical,
  width = 10,
  height = 7,
  dpi = 300,
  bg = "white"
)

ggsave(
  filename = "images/montgomery_housing_burden_categorical.pdf",
  plot = housing_map_categorical,
  width = 11,
  height = 7,
  bg = "white"
)

ACS_housing_geo %>%
  sf::st_drop_geometry() %>%
  summarise(
    total_tracts = n(),
    above_county_rate = sum(severe_burden_rate > 25.214924),
    at_or_below_county_rate = sum(severe_burden_rate <= 25.214924),
    pct_above_county = round(
      mean(severe_burden_rate > 25.214924) * 100,
      1
    )
  )

ACS_housing_geo %>%
  sf::st_drop_geometry() %>%
  arrange(desc(severe_burden_rate)) %>%
  select(
    GEOID,
    NAME,
    eligible_renters,
    severe_burden_count,
    severe_burden_rate,
    severeM
  ) %>%
  slice_head(n = 10)

ACS_housing_geo %>%
  sf::st_drop_geometry() %>%
  mutate(
    above_county_rate =
      severe_burden_rate > 25.214924
  ) %>%
  group_by(above_county_rate) %>%
  summarise(
    census_tracts = n(),
    severe_households = sum(severe_burden_count),
    eligible_renters = sum(eligible_renters),
    .groups = "drop"
  ) %>%
  mutate(
    share_of_severe_households = round(
      severe_households /
        sum(severe_households) * 100,
      1
    )
  )

# --------------------------------------------
# 17.8 SUMMARY BY HOUSING BURDEN CATEGORY
# --------------------------------------------

ggsave(
  filename = "images/montgomery_housing_burden_categorical.png",
  plot = housing_map_categorical,
  width = 12,
  height = 9,
  dpi = 300,
  bg = "white"
)

housing_category_summary <- ACS_housing_geo %>%
  st_drop_geometry() %>%
  group_by(burden_category) %>%
  summarise(
    census_tracts = n(),
    
    eligible_renters = sum(eligible_renters),
    
    severe_households = sum(severe_burden_count),
    
    .groups = "drop"
  ) %>%
  mutate(
    pct_of_tracts = round(
      census_tracts / sum(census_tracts) * 100,
      1
    ),
    
    pct_of_severe_households = round(
      severe_households / sum(severe_households) * 100,
      1
    )
  )

print(housing_category_summary)
