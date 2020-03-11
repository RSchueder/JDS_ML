# Loading libraries -------------------------------------------------------
library(FactoMineR)
library(factoextra)
library(paran)
library(psych)
library(Rtsne)
library(tidyverse)
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

pca_base_df <-
  select(
    pca_df,
    -emission_air,
    -emission_water,
    -emission_ww,
    -emission_soil,
    -kbiodeg,
    -log_kow,
    -molar_mass,
    -ks,
    -sub_groups
  )

pca_all <- PCA(pca_df, quanti.sup = 78:80, quali.sup = 81, graph = TRUE)
pca_base <- prcomp(pca_base_df, scale. = TRUE)
 

summary(pca_all)
dimdesc(pca_all, axes = 1:2)
pca_all$eig[,2][1:30]
pca_all$eig[,3][1:30]
pca_all$var

fviz_cos2(pca_all, choice = "var", axes = 1, top = 10)
fviz_cos2(pca_all, choice = "var", axes = 2, top = 10)
fviz_contrib(pca_all, choice = "var", axes = 1, top = 10)
fviz_contrib(pca_all, choice = "var", axes = 2, top = 10)

fviz_screeplot(pca_all, ncp = 20)
get_eigenvalue(pca_all)

# parallel analysis #
paran_df <- select(pca_df, subs_value, AREA:CumAreakkm2)
paran_df <- as.data.frame(paran_df[complete.cases(paran_df), ])


paran(paran_df, graph = TRUE)
fa.parallel(paran_df)

# t-SNE #
tsne_output <- Rtsne(paran_df, perplexity = 50, max_iter = 1200, dims = 3, check_duplicates = FALSE)



