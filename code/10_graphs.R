library(tidyverse)
library(gt)
library(viridis)
library(sf)
library(caret)
library(wesanderson)
library(lubridate)
library(ggmap)
library(patchwork)

sf_use_s2(FALSE)

base <- st_read("./data/base_polygons/chaco_seco.geojson")
base <- st_transform(base, crs = 4326)

#OTBN:
filenames <- list.files("data/otbn", pattern="*.geojson", full.names=TRUE)
ldf <- lapply(filenames, st_read)
# 
otbn <- bind_rows(ldf, .id = "column_label")
otbn <- st_transform(otbn, crs = 4326)
# 
otbn <- st_make_valid(otbn)

otbn_group <- otbn_group <- otbn %>% group_by(Provincia, Cat_cons)  %>% 
  summarize(geometry = st_union(geometry))

otbn_pc <- st_intersection(base, otbn) 

#Preds:
predictions <- st_read('./data/test_predictions.geojson')


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

predictions %>% 
  distinct() %>%
  group_by(model, prediction) %>%
  summarise(n=n()) %>%
  ggplot(aes(x = prediction, y =n, fill = model))+
  geom_col(position = 'dodge')+
  scale_fill_manual(values = wes_palette("BottleRocket2"))+
  labs(x = "Categoría predicha",
       fill = "Modelo")+
  theme_minimal()

ggsave('img/08_cant_puntos.png')

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
  scale_fill_manual(values = wes_palette("BottleRocket2"))+
  labs(#title = "Gráfico 4. Métricas de evaluación",
    x = "Métrica",
    y = "",
    fill = "Modelo")+
  scale_y_continuous(limits=c(0,1))+
  theme_minimal()

ggsave('img/01_clasif_report.png')

## NDVI 

error_data <- predictions %>%
  as_tibble() %>%
  group_by(model, error) %>%
  summarise_at(vars(year_0:year_19), median) %>%
  filter(error %in% c("TP", "FP")) 

error_data <- error_data %>% pivot_longer(cols = year_0:year_19, names_to = "year", values_to = "NDVI")# %>%
#pivot_wider(names_from = "error", values_from="NDVI") %>% 
#group_by(model, year) %>%
#mutate(dif_ndvi = TP-FP)

error_data <- error_data %>% mutate(year = as.numeric(extract_numeric(year)))

ggplot(error_data, aes(x = year, y = NDVI, color = model))+
  geom_line()+
  geom_point()+
  scale_color_manual(values = wes_palette("BottleRocket2"))+
  facet_wrap(vars(error))+
  labs(x = "Año",
       color = "Modelo",
       y = "NDVI")+
  theme_minimal()

ggsave('img/09_NDVI_models.png')


# Mapa OTBN

cat_colores <- c("firebrick1", "yellow1","limegreen")

bbox <- st_bbox(base)

names(bbox) <- c("left", "bottom", "right", "top")

#mapa_PC <- get_stamenmap(bbox, zoom = 7, maptype = "toner-lines")
mapa_PC_hyb <- get_stamenmap(bbox, zoom = 7, maptype = "toner-hybrid")


p1 <- ggmap(mapa_PC_hyb)+
  geom_sf(data = otbn_group,aes(fill=Cat_cons), color = NA, inherit.aes = FALSE)+
  scale_fill_manual(values = cat_colores)+
  theme_void()+
  labs(fill = "Categoría de \nconservación")+
  theme(legend.position = "bottom",
        legend.direction = "horizontal",
        legend.key.size = unit(0.5, 'cm'),
        legend.title = element_text(size=10))

ggsave('img/05_plot_otbn.png', p1)
  

## Preds y OTBN

preds_1 <- predictions %>% 
  select(label, predictions_lr, predictions_rf, predictions_xgb) %>%
  pivot_longer(cols = c(label, predictions_lr, predictions_rf, predictions_xgb), 
               names_to = "modelo", values_to = "pred") %>%
  mutate_at(vars(modelo), ~case_when(
    . == "label" ~ "Deforestación real",
    . == "predictions_lr" ~ "Regresión logística",
    . == "predictions_rf" ~ "Random Forest",
    . == "predictions_xgb" ~ "XGBoost",
  )) %>%
  filter(pred == 1)

preds_1 <-preds_1 %>% st_transform(crs = 4326)

tb1 <- preds_1 %>% 
  as_tibble()%>%
  group_by(modelo) %>%
  summarise(n = n ()) %>%
  mutate(Cat_cons = NA)

preds_prueba <- st_intersection(preds_1, otbn) 

tb2 <- preds_prueba %>% 
  as_tibble() %>%
  group_by(modelo, Cat_cons) %>%
  summarise(n=n()) %>%
  mutate(perc = n/sum(n)*100) %>%
  select(-n) %>%
  pivot_wider(id_cols = Cat_cons, names_from = modelo, values_from = perc)

writexl::write_xlsx(tb2, './tables/01_pred_otbn.xlsx')

p2 <- ggmap(mapa_PC_hyb)+
  geom_sf(data = st_jitter(preds_prueba), aes(color = Cat_cons), inherit.aes = FALSE)+
  facet_wrap(vars(modelo))+
  scale_color_manual(values = cat_colores)+
  labs(color = "Cat. cons")+
  theme_void()+
  theme(legend.position = "bottom",
        legend.direction = "horizontal",
        legend.key.size = unit(0.5, 'cm'),
        legend.title = element_text(size=10)
        )

ggsave('img/06_plot_preds_otbn.png', p2)

# Modelo viejo

data <- read_csv("./data/preds/old_model.csv")

data_filter <- data %>% filter(label == 0 & predicted_landcover != 0)

table_landcover <- data_filter %>% group_by(b1) %>%
  summarise(n=n()) %>%
  arrange(-n) %>%
  ungroup()%>%
  mutate(perc = round(n/sum(n)*100,2)) %>%
  select(trayectoria = b1, perc) %>%
  slice(0:10)

gt(table_landcover)%>%
  tab_options(table.font.size = px(18)) %>%
  opt_table_font(
    font = list(
      google_font(name = "Times New Roman"))
  )  %>% gtsave("img/tab_fp_lc.png", expand = 10)
