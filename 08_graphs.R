library(tidyverse)
library(viridis)
library(sf)
library(caret)
library(gt)
library(wesanderson)
library(lubridate)
library(patchwork)
library(ggmap)

sf_use_s2(FALSE)

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

preds_1 <- predictions %>% filter(predictions_rf== 1)
preds_1 <-preds_1 %>% st_transform(crs = 4326)

preds_prueba <- st_intersection(preds_1, otbn) 

tb1<- preds_prueba %>% group_by(Cat_cons) %>%
  summarise(n=n()) %>%
  ungroup() %>% 
  add_row(Cat_cons = NA, n = nrow(preds_1)-nrow(preds_prueba)) %>%
  mutate(perc = n/sum(n)*100)

tb2 <- preds_prueba %>% group_by(Cat_cons) %>%
  summarise(n=n()) %>%
  ungroup() %>% 
  mutate(perc = n/sum(n)*100)

p2 <- ggmap(mapa_PC_hyb)+
  geom_sf(data = st_jitter(preds_prueba), aes(color = Cat_cons), inherit.aes = FALSE)+
  scale_color_manual(values = cat_colores)+
  labs(title = "Deforestación \npredicha",
       subtitle = "en 2019",
       color = "Cat. cons")+
  theme_void()+
  theme(legend.position = "bottom",
        legend.direction = "horizontal",
        legend.key.size = unit(0.5, 'cm'),
        legend.title = element_text(size=10)
  )

ggsave('img/06_plot_preds_otbn.png', p2)

preds_2 <- predictions %>% filter(label== 1)
preds_2 <-preds_2 %>% st_transform(crs = 4326)

preds_prueba_2 <- st_intersection(preds_2, otbn) 

tb3 <- preds_prueba_2 %>% group_by(Cat_cons) %>%
  summarise(n=n()) %>%
  add_row(Cat_cons = NA, n = nrow(preds_1)-nrow(preds_prueba_2)) %>%
  mutate(perc = n/sum(n)*100)

tb4 <- preds_prueba_2 %>% group_by(Cat_cons) %>%
  summarise(n=n()) %>%
  mutate(perc = n/sum(n)*100)

p3 <- ggmap(mapa_PC_hyb)+
  geom_sf(data = preds_prueba_2, aes(color = Cat_cons), inherit.aes = FALSE, show.legend = FALSE)+
  scale_color_manual(values = cat_colores)+
  labs(title = "Verdaderos puntos \ndeforestados",
       subtitle = "en 2019",
       color = "Cat. cons")+
  theme_void()

p4 <- p2 + p3


ggsave('img/07_otbn_defo.png', p4)

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
