# Loading libraries -------------------------------------------------------
library(tidyverse)
library(naniar)
library(vtreat)
library(ranger)
library(xgboost)

# Loading data ------------------------------------------------------------
df <- read_rds("data/modified/compact_data.rds")

# Cleaning data for feature table #   
df <- select(df, -SUBID:-Concentration, -valid_measurement, -sub_groups)

# first test removing al missing values (for now) #
df <- na.omit(df)

# create test and training data #
N <- nrow(df)
target <- round(0.75 * N)
gp <- runif(N)

# splitting the data
df_train <- df[gp < 0.75, ] 
df_test <- df[gp >= 0.75, ]

# Cross validation Plan #
nRows <- nrow(df)
splitPlan <- kWayCrossValidation(nRows, 3, NULL, NULL)


fmla <- as.formula("subs_value ~ .")

# test model  random forrest #
(subs_model_rf <-
  ranger(
    formula = fmla,
    data = df_train,
    num.trees = 500,
    respect.unordered.factors = "order"
  ))

df_test$rf_pred <- predict(subs_model_rf, df_test)$predictions

# RMSE on test data
mutate(df_test, residual = subs_value - rf_pred) %>% 
  summarise(rmse = sqrt(mean(residual ^2)))

# plot model performance
ggplot(df_test, aes(x = rf_pred, y = subs_value)) + 
  geom_point() + 
  geom_abline()

rf_pred <- df_test$rf_pred
df_test <- select(df_test, -rf_pred)



# test model xgboost # 
df_train_xg <- select(df_train, -subs_value)
df_test_xg <- select(df_test, -subs_value)

cv <-
  xgb.cv(
    data = as.matrix(df_train_xg),
    label = df_train$subs_value,
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

subs_model_xgb <- xgboost(data = as.matrix(df_train_xg),
                          label = df_train$subs_value,
                          nrounds = 15,
                          objective = "reg:linear",
                          eta = 0.3,
                          depth = 6,
                          verbose = 0)

df_test$xgb_pred <- predict(subs_model_xgb, as.matrix(df_test_xg))


mutate(df_test, residual = subs_value - xgb_pred) %>% 
  summarise(rmse = sqrt(mean(residual ^2)))

ggplot(df_test, aes(x = xgb_pred, y = subs_value)) + 
  geom_point() + 
  geom_abline()


df_test$rf_pred <- rf_pred 

# check both models #
mutate(df_test, residual_rf = subs_value - rf_pred,
       residual_xgb = subs_value - xgb_pred) %>% 
  summarise(rmse_rf = sqrt(mean(residual_rf ^2)),
            rmse_xgb = sqrt(mean(residual_xgb ^2)))


