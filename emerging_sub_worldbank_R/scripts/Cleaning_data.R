# Kevin Ouwerkerk
# 2019-11-18

# Loading libraries -------------------------------------------------------
library(tidyverse)
library(readxl)
library(RSQLite)
library(naniar)
library(arrow)

# Loading data ------------------------------------------------------------

geo_hydro <- read_tsv("data/raw/GeoData.txt") %>% 
  filter(HAROID == 9600704)

catch <- read_excel("data/raw/NewHypeSchematisation.xlsx", sheet = "CumCat") %>% 
  select(SUBID, CumCat_km2)
  
measurements <-
  read_excel(path = "data/raw/JDS_Query met pivot.xlsx", sheet = "DBQuery") %>%
  filter(Sample_Matrix == "Water - Surface water", CAS_No != "N/A") %>% 
  select(
    Station_Code,
    Substance,
    CAS_No,
    H_Unit,
    Concentration,
    `Data value`,
    `Valid measurement`
  ) %>%
  rename(subs_value = `Data value`,
         valid_measurement = `Valid measurement`)

measurements$H_Unit[measurements$H_Unit == "mg/L"] <- "mg/l"


measurements_mapping <- read_csv2(file = "data/raw/MappingJDS_Define.csv") %>% 
  filter(HAROID == 9600704) %>% 
  select(station_co, SUBID, distance_t, CumAreakkm2)


demo <- read_excel(path = "data/raw/copy_locators_hypefinal_Nov2017.xlsx", sheet = "locators") %>% 
  select(SC, CountryCorrFinal, GDPEP)

countries <- read_excel(path = "data/raw/copy_locators_hypefinal_Nov2017.xlsx", sheet = "Countries") %>% 
  rename(country = `Countries in Ehype`, country_nr = Nr) %>% 
  select(country, country_nr)

country_gdpep <- read_tsv("data/raw/GeoData.txt") %>% 
  select(SUBID) %>% 
  left_join(demo, by = c("SUBID" = "SC")) %>% 
  left_join(countries, by = c("CountryCorrFinal" = "country")) %>% 
  group_by(CountryCorrFinal, country_nr) %>% 
  summarise(coun_gdpep = sum(GDPEP, na.rm = TRUE)) %>% 
  ungroup()
  
agrlu <- read_excel(path = "data/raw/copy_locators_hypefinal_Nov2017.xlsx", sheet = "LU") %>% 
  select(SUBID, Agr) %>% 
  rename(area_agr = Agr)

demo <- left_join(demo, countries, by = c("CountryCorrFinal" = "country")) %>% 
  left_join(agrlu, by = c("SC" = "SUBID")) %>% 
  left_join(country_gdpep, by = c("CountryCorrFinal", "country_nr")) %>% 
  mutate(frac_GDPEP = GDPEP / coun_gdpep)


conn <- dbConnect(RSQLite::SQLite(), "data/raw/substance_properties.db")
dbListTables(conn)

sub_props <-
  dbGetQuery(
    conn,
    "SELECT ID, CAS, property, value FROM substance_properties WHERE property IN ('Molar mass [Da]', 'log Kow', 'Kbiodeg [1/s]', 'Ks')"
  ) %>%
  mutate(value = as.numeric(value)) %>%
  filter(CAS %in% measurements$CAS_No) %>%
  spread(key = property, value = value) %>%
  select(CAS, `Kbiodeg [1/s]`, `log Kow`, `Molar mass [Da]`, Ks) %>%
  group_by(CAS) %>%
  summarise(
    molar_mass = mean(`Molar mass [Da]`, na.rm = TRUE),
    log_kow = mean(`log Kow`, na.rm = TRUE),
    kbiodeg = mean(`Kbiodeg [1/s]`, na.rm = TRUE),
    ks = mean(Ks, na.rm = TRUE)
  ) %>% 
  ungroup()

sub_groups <- dbGetQuery(
  conn,
  "SELECT CAS, CODE FROM substances"
) %>% 
  filter(CAS %in% measurements$CAS_No) %>%
  mutate(CODE = tolower(CODE)) %>% 
  mutate(pest = str_detect(CODE, "pest"),
         pharma = str_detect(CODE, "pharma"),
         reach = str_detect(CODE, "reach")
         ) #%>% 
  # select(-CODE)

sub_groups <- sub_groups[!duplicated(sub_groups$CAS), ]


# Joining data  -----------------------------------------------------------

data_tot <-
  left_join(measurements_mapping,
            measurements ,
            by = c("station_co" = "Station_Code")) %>%
  left_join(geo_hydro, by = "SUBID") %>%
  left_join(catch, by = "SUBID") %>%
  left_join(demo, by = c("SUBID" = "SC")) %>%
  left_join(sub_props, by = c("CAS_No" = "CAS")) %>% 
  left_join(sub_groups, by = c("CAS_No" = "CAS"))

data <- data_tot %>%
  select(
    HAROID,
    MAINDOWN,
    SUBID,
    CountryCorrFinal,
    country_nr,
    LAKEREGION,
    REGION,
    WQPARREG,
    POURX,
    POURY,
    TARGETX,
    TARGETY,
    CENTERX,
    CENTERY,
    LATITUDE,
    LONGITUDE,
    station_co,
    Substance,
    CAS_No,
    H_Unit,
    Concentration,
    subs_value,
    valid_measurement,
    kbiodeg,
    log_kow,
    molar_mass,
    ks,
    reach,
    pest,
    pharma,
    AREA,
    area_agr,
    UPAREA,
    RIVLEN,
    ELEV_MEAN,
    ELEV_STD,
    SLOPE_MEAN,
    RELIEF,
    SLC_1:CumCat_km2,
    GDPEP,
    frac_GDPEP,
    distance_t,
    CumAreakkm2
  ) %>% 
   mutate(  # recalculating units to one standard #
     subs_value = case_when(
       H_Unit == "mg/l" ~ subs_value * 1000,
       H_Unit == "mg/kg" ~ subs_value * 1000,
      TRUE ~ subs_value
    ),
    H_Unit = case_when(H_Unit == "mg/l" ~ "µg/l",
                       H_Unit == "mg/kg" ~ "µg/kg",
                       TRUE ~ H_Unit)
  ) %>% 
  filter(H_Unit != "µg/kg")

# removing missing measurement
data <- data[!is.na(data$subs_value), ]

# calculate fraction agricultural are for each subid #
data <- mutate(data, f_agr = area_agr / AREA)
# adding flag for substances that belong to multiple groups
data$mult_groups <- rowSums(data[,c('reach', 'pharma', 'pest')], na.rm = TRUE)

# making sure that every substance only belongs to one group using priorities #
data <-
  mutate(
    data,
    reach_bin = if_else(reach == TRUE & mult_groups == 1, 1 , 0),
    pharma_bin = if_else(
      pharma == TRUE & mult_groups == 1 | pharma == TRUE & pest != TRUE & mult_groups > 1,
      1 , 0),
    pest_bin = if_else(pest == TRUE, 1 , 0, missing = 0)
  )
# making on column for the groups
data$sub_groups <- case_when(data$reach_bin == 1 ~ "reach",
                             data$pharma_bin == 1 ~ " pharma",
                             data$pest_bin == 1 ~ "pest")

# Obtaining emissions data ------------------------------------------------

emission_files <- list.files(path = "data/raw/emission-data/", pattern = "*.dbg", full.names = TRUE)

emission_data <- NULL

# file <- "data/raw/emission-data/espaceCAS_100-41-4.dbg"
for (file in emission_files) {
  
cas <- str_extract(basename(file), "\\d{1,}-\\d{1,2}-\\d{1}")
  
df <-
  read_table2(
    file = file,
    skip = 2,
    col_names = FALSE,
    col_types =  cols(X1 = col_integer(),
                      X2 = col_double(),
                      X3 = col_double())
  )

skip <- which(is.na(df$X1))

df <- df[-c(1:skip[2]), ]
colnames(df) <- c("country_nr" ,"emission_air_raw", "emission_water_raw", "emission_ww_raw", "emission_soil_raw", "unknown")
df$cas <- cas

emission_data <- bind_rows(emission_data, df)

}

# cleaning and joining emission data #
emission_data <- select(emission_data, country_nr, cas, emission_air_raw:emission_soil_raw)

data <- left_join(data, emission_data, by = c("country_nr" = "country_nr" , "CAS_No" = "cas"))

# calculating emissions based on substance group # 
data <- mutate(
  data,
  emission_air = case_when(
    pest_bin == 1 ~ emission_air_raw * f_agr,
    pest_bin != 1 ~ emission_air_raw * frac_GDPEP
  ),
  emission_water = case_when(
    pest_bin == 1 ~ emission_water_raw * f_agr,
    pest_bin != 1 ~ emission_water_raw * frac_GDPEP
  ),
  emission_ww = case_when(
    pest_bin == 1 ~ emission_ww_raw * f_agr,
    pest_bin != 1 ~ emission_ww_raw * frac_GDPEP
  ),
  emission_soil = case_when(
    pest_bin == 1 ~ emission_soil_raw * f_agr,
    pest_bin != 1 ~ emission_soil_raw * frac_GDPEP
  )
)

# creating intermediate datset #
data_intermediate <- data

# create data for later use #
data <- select(
  data,
  -HAROID,
  -REGION,
  -MAINDOWN,
  -LAKEDATAID,
  -LAKE_DEPTH,  # always the same
  -ICATCH,  # always the same
  -loc_sp,
  -loc_in,
  -frac_GDPEP,
  -f_agr,
  -emission_air_raw,
  -emission_water_raw,
  -emission_ww_raw,
  -emission_soil_raw,
  -mult_groups,
  -reach,
  -pest,
  -pharma,
  -drydep_n2,  # drydep_n1 & drydep_n2 are the same?
  -WQPARREG  # always the same
  )

#miss_var_summary(data)

# Writing data to disk ----------------------------------------------------

# intermediate
write_csv2(data_intermediate, "data/modified/intermediate_data.csv")
write_rds(data_intermediate, "data/modified/intermediate_data.rds")
write_parquet(data_intermediate, sink = "data/modified/intermediate_data.parquet")

# for later use #
write_csv2(data, "data/modified/compact_data.csv")
write_rds(data, "data/modified/compact_data.rds")
write_parquet(data, "data/modified/compact_data.parquet")
