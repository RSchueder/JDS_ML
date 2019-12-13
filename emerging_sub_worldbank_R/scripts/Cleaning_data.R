# Kevin Ouwerkerk
# 2019-11-18

# Loading libraries -------------------------------------------------------
library(tidyverse)
library(readxl)
library(RSQLite)

# Loading data ------------------------------------------------------------
geo_hydro <- read_tsv("data/raw/GeoData.txt") %>% 
  filter(HAROID == 9600704)

catch <- read_excel("data/raw/NewHypeSchematisation.xlsx", sheet = "CumCat") %>% 
  select(SUBID, CumCat_km2)
  
measurements <- read_excel(path = "data/raw/JDS_Query met pivot.xlsx", sheet = "DBQuery") %>% 
  select(Station_Code, Substance, CAS_No, H_Unit, `Data value`) %>% rename(subs_value = `Data value`)
  
measurements_mapping <- read_csv2(file = "data/raw/MappingJDS_Define.csv") %>% 
  filter(HAROID == 9600704) %>% 
  select(station_co, SUBID, distance_t, CumAreakkm2)

demo <- read_excel(path = "data/raw/copy_locators_hypefinal_Nov2017.xlsx", sheet = "locators") %>% 
  select(SC, CountryCorrFinal, GDPEP)

conn <- dbConnect(RSQLite::SQLite(), "data/raw/substance_properties.db")
dbListTables(conn)

sub_props <-
  dbGetQuery(
    conn,
    "SELECT ID, CAS, property, value FROM substance_properties WHERE property IN ('Molar mass [Da]', 'log Kow', 'HL in water')"
  ) %>%
  mutate(value = as.numeric(value)) %>%
  filter(CAS %in% measurements$CAS_No) %>% 
  spread(key = property, value = value) %>% 
  select(CAS, `HL in water`, `log Kow`, `Molar mass [Da]`)


## joining data ##
data <-
  left_join(measurements_mapping,
            measurements ,
            by = c("station_co" = "Station_Code")) %>%
  left_join(geo_hydro, by = "SUBID") %>%
  left_join(catch, by = "SUBID") %>%
  left_join(demo, by = c("SUBID" = "SC")) %>%
  #left_join(sub_props, by = c("CAS_No" = "CAS")) %>%
  select(
    HAROID,
    MAINDOWN,
    SUBID,
    CountryCorrFinal,
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
    endpoint_unit,
    H_Unit,
    subs_value,
    `HL in water`,
    `log Kow`,
    `Molar mass [Da]`,
    AREA,
    UPAREA,
    RIVLEN,
    ELEV_MEAN,
    ELEV_STD,
    SLOPE_MEAN,
    RELIEF,
    SLC_1:CumCat_km2,
    GDPEP,
    distance_t,
    CumAreakkm2
  )


## writing data to disk ##
write_csv2(data, "data/modified/test-data.csv")
write_rds(data, "data/modified/test-data.rds")
