# Loading libraries -------------------------------------------------------
library(tidyverse)
library(naniar)
library(ranger)
library(xgboost)
# Loading data ------------------------------------------------------------
df <- read_rds("data/modified/compact_data.rds")

# Cleaning data for feature table #   
df <- select(df, -SUBID:-Concentration, -valid_measurement, -sub_groups)

# first test removing al missing values (for now) #
df <- na.omit(df)

fmla <- "subs_value ~ ."

# test model  random forrest #
(subs_model_rf <-
  ranger(
    formula = fmla,
    data = df,
    num.trees = 500,
    respect.unordered.factors = "order"
  ))

# test model xgboost # 
cv <-
  xgb.cv(
    data = as.matrix(df),
    label = df$subs_value,
    nrounds = 100,
    nfold = 5,
    objective = "reg:linear",
    eta = 0.3,
    max_depth = 6,
    early_stopping_rounds = 10,
    verbose = 0
  )

elog <- cv$evaluation_log

elog %>% 
  summarize(ntrees.train = which.min(train_rmse_mean),   # find the index of min (train_rmse_mean)
            ntrees.test  = which.min(test_rmse_mean)) 

subs_model_xgb <- xgboost(data = as.matrix(df),
                          label = df$subs_value,
                          nrounds = 20,
                          objective = "reg:linear",
                          eta = 0.3,
                          depth = 6,
                          verbose = 0)
