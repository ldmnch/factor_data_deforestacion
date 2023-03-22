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

data <- read_csv("/home/laia/Descargas/2500_trees_100_nodes_1_variables_per_split.csv")

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
