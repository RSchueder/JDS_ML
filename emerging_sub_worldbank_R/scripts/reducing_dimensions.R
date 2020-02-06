# Loading libraries -------------------------------------------------------
library(tidyverse)
library(FactoMineR)
library(factoextra)
# Loading data ------------------------------------------------------------

df <- read_rds("data/modified/compact_data.rds")


# PCA #
pca_df <-
  select(
    df,
    -SUBID,
    -CountryCorrFinal,
    -country_nr,
    -LAKEREGION,
    -POURX,
    -POURY,
    -TARGETX,
    -TARGETY,
    -CENTERX,
    -CENTERY,
    -LATITUDE,
    -LONGITUDE,
    -station_co,
    -Substance,
    -CAS_No,
    -CAS_No,
    -H_Unit,
    -Concentration,
    -valid_measurement
  )

pca_all <- pca_output_all <- PCA(pca_df, quanti.sup = 99:101, quali.sup = 102, graph = TRUE)

summary(pca_all)
dimdesc(pca_all, axes = 1:2)
pca_all$eig[,2][1:20]
pca_all$eig[,3][1:20]
pca_all$var

fviz_cos2(pca_all, choice = "var", axes = 1, top = 10)
fviz_cos2(pca_all, choice = "var", axes = 2, top = 10)
fviz_contrib(pca_all, choice = "var", axes = 1, top = 10)
fviz_contrib(pca_all, choice = "var", axes = 2, top = 10)









