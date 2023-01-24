library(tidyverse)
library(viridis)
library(sf)
library(caret)
library(gt)
library(wesanderson)
library(lubridate)

predictions <- st_read('/home/laia/Escritorio/factor_data/factor_data_deforestacion/data/preds/test_predictions.dbf')

predictions <- predictions %>% pivot_longer(cols = c(prediction:predicti_2), names_to  = 'model', values_to = 'prediction') %>%
  mutate(model = case_when(
    model == "prediction" ~ "RF",
    model == "predicti_1" ~ "XGB",
    model == "predicti_2" ~ "LR"
  ))

predictions <- predictions %>%
  mutate(error = case_when(
    label_0 == 1 & prediction == 1 ~ "TP",
    label_0 == 1 & prediction == 2 | label_0 == 1 & prediction == 0 ~ "FN",
    label_0 == 0 & prediction == 1 | label_0 == 2 & prediction == 1 ~ "FP",
    TRUE ~ "TN"))

ggplot(predictions, aes(x = prediction, fill = model))+
  geom_bar(position = 'dodge')+
  scale_fill_viridis_d()+
  theme_minimal()

ggplot(predictions %>% filter(error != "TN"), aes(color = error))+
  geom_sf()+
  facet_wrap(vars(model))+
  scale_color_manual(values = wes_palette("Darjeeling1"))+
  theme_minimal()

### Reportes de clasificación 

reporte_rf <- read_csv('/home/laia/Escritorio/factor_data/factor_data_deforestacion/data/preds/classification_report_random_forest.csv')
reporte_lr <- read_csv('/home/laia/Escritorio/factor_data/factor_data_deforestacion/data/preds/classification_report_reg_log.csv')
reporte_xgb <- read_csv('/home/laia/Escritorio/factor_data/factor_data_deforestacion/data/preds/classification_report_xgb.csv')

reporte_rf$model <- "RF"
reporte_lr$model <- "LR"
reporte_xgb$model <- "XGBoost"

clasif_report <- rbind(reporte_rf, reporte_lr, reporte_xgb)

clasif_report <- clasif_report %>% rename(
  "label_0" = '0',
  "label_1" = '1',
  "label_2" = "2")

ggplot(clasif_report %>% filter(metric != "support"), aes(x = metric, y = label_1, fill = model))+
  geom_col(position = 'dodge')+
  scale_fill_viridis_d()+
  #scale_fill_manual(values = wes_palette("BottleRocket2"))+
  labs(x = "Métrica",
       y = "Clasificación deforestación",
       fill = "Modelo")+
  theme_minimal()

## NDVI 

error_data <- predictions %>%
  #filter(label_0 == 1) %>%
  group_by(model, error) %>%
  summarise_at(vars(NDVI_2000:NDVI_2019), median) 

error_data <- error_data %>% pivot_longer(cols = NDVI_2000:NDVI_2019, names_to = "year", values_to = "NDVI") 
error_data <- error_data %>% mutate(year = as.numeric(extract_numeric(year)))

ggplot(error_data, aes(x = year, y = NDVI, color = error))+
  geom_line()+
  facet_wrap(vars(model),
             ncol = 2)+
  labs(x = "Año",
       color = "Clasificación")+
  theme_minimal()

### Landcover

preds_landcover <- st_read('/home/laia/Escritorio/factor_data/factor_data_deforestacion/data/preds/test_predictions_landcover_google.shp')

preds_landcover <- preds_landcover %>% pivot_longer(cols = c(prediction:predicti_2), names_to  = 'model', values_to = 'prediction') %>%
  mutate(model = case_when(
    model == "prediction" ~ "RF",
    model == "predicti_1" ~ "XGB",
    model == "predicti_2" ~ "LR"
  ))

preds_landcover <- preds_landcover %>%
  mutate(error = case_when(
    label_0_le == 1 & prediction == 1 ~ "TP",
    label_0_le == 1 & prediction == 2 | label_0_le == 1 & prediction == 0 ~ "FN",
    label_0_le == 0 & prediction == 1 | label_0_le == 2 & prediction == 1 ~ "FP",
    TRUE ~ "TN"))

preds_landcover <- preds_landcover %>% mutate(b1 = as.integer(b1))

count_errors <- preds_landcover %>% group_by(model, error, label) %>%
  summarise(n=n()) %>%
  arrange(desc(n)) #%>%
  #top_n(n = 5, wt = n)

ggplot(count_errors %>% filter(error != "TP"), aes(x = error, y = n, fill = as.factor(label)))+
  geom_col(position = 'fill')+
  #guides(fill=guide_legend(label.vjust = -7,label.position = "bottom"))+
  scale_fill_viridis_d(option = "plasma")+
  facet_wrap(vars(model))+
  theme_minimal() +
  theme(legend.position = "bottom", 
        legend.direction = "horizontal") +
  labs(fill = "Cluster de \nuso de suelo")

ggplot(count_errors %>% filter(error != "TP"), aes(color = as.factor(b1)))+
  geom_sf()+
  facet_wrap(vars(model))+
  #guides(color="none")+
#  scale_color_manual(values = wes_palette("Darjeeling1"))+
  theme_minimal()

