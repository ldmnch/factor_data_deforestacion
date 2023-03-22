library(tidyverse)
library(viridis)
library(sf)
library(caret)
library(gt)
library(wesanderson)
library(lubridate)

predictions <- st_read('./data/test_predictions.geojson')

predictions <- predictions %>% pivot_longer(cols = c(predictions_rf:predictions_lr), names_to  = 'model', values_to = 'prediction') %>%
  mutate(model = case_when(
    model == "predictions_rf" ~ "RF",
    model == "predictions_lr" ~ "LR",
    model == "predictions_xgb" ~ "XGB"
  ))

predictions <- predictions %>%
  mutate(error = case_when(
    label == 1 & prediction == 1 ~ "TP",
    label == 1 & prediction == 2 | label == 1 & prediction == 0 ~ "FN",
    label == 0 & prediction == 1 | label == 2 & prediction == 1 ~ "FP",
    TRUE ~ "TN"))

predictions %>% 
  distinct() %>%
  group_by(model, prediction) %>%
  summarise(n=n()) %>%
  ggplot(aes(x = prediction, y =n, fill = model))+
  geom_col(position = 'dodge')+
  scale_fill_viridis_d()+
  labs(title = "Gráfico 3. Cantidad de puntos clasificados para cada categoría",
       subtitle = "según modelo")+
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

ggplot(clasif_report %>% filter(metric != "support"), aes(x = model, y = label_1, fill = metric))+
  geom_col(position = 'dodge')+
  scale_fill_viridis_d()+
  scale_fill_manual(values = wes_palette("BottleRocket2"))+
  labs(title = "Gráfico 4. Métricas de evaluación",
       x = "Métrica",
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
  labs(title = "Gráfico 5. Media de NDVI anual según tipo de error",
       x = "Año",
       color = "Clasificación")+
  theme_minimal()

### Landcover

landcover <- st_read('/home/laia/Descargas/landcover_test_set (1).geojson')

ggplot(landcover, aes(color = as.factor(b1_clust))) +
  geom_sf()+
  scale_color_viridis_d(option = "plasma")+
  theme_minimal()


ggplot(predictions %>% filter(model == "RF" & error %in% c("FN", "FP")), aes(color = error))+
  geom_sf()+
  facet_wrap(vars(model))+
  scale_color_manual(values = wes_palette("Darjeeling1"))+
  theme_minimal()



