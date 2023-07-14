library(sf)
library(tidyverse)

#1sf_use_s2(FALSE)

predictions <- st_read('./data/test_predictions.geojson')
df_old <- st_read('./data/base_polygons/deforestacion_15-19.geojson')

#df_old <- st_make_valid(df_old)

predictions <- predictions %>% pivot_longer(cols = c(predictions_rf:predictions_xgb), names_to  = 'model', values_to = 'prediction') %>%
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

intersections <- st_within(predictions, df_old)  %>% lengths > 0# Chequear con st_within / st_contain

intersections <- predictions %>% st_intersection(df_old, left=FALSE)


group_int <- intersections %>% 
  as_tibble()%>% filter(error == "FP" & Fecha == 2019) 
  group_by(error, model, Fecha) %>%
  count() 
  
group_preds <- predictions %>% 
  as_tibble()%>%
  group_by(error, model) %>%
  count() 

  
group_preds %>% 
  filter(model == "RF") %>%
  bind_rows(group_int%>% 
              filter(model == "RF"))

ggplot()+
  geom_sf(data = df_old)+
  geom_sf(data = intersections %>% filter(error == "FP" & Fecha == 2019), aes(color= error), inherit.aes = FALSE)

## que onda los puntos que se solapan de deforestación real, con FP y 2019? 
