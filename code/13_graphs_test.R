#library(stars)
library(sf)
library(ggplot2)
library(tidyverse)
library(ggmap)

region1 <- st_read("data/base_polygons/MISIONES.json")
region2 <- st_read("data/base_polygons/ENTRERIOS.json")

region <- rbind(region1, region2)

test_misiones <- st_read("data/test_region/data_final_preds.geojson")
test_er <- st_read("data/test_region/entre_rios_data_final_preds.geojson") %>%
  mutate(provincia = "Entre Rios")

test <- rbind(test_misiones, test_er)

test <- test %>% unique()

test <- test %>%
  pivot_longer(cols = c(RF_pred, XGB_pred),
               names_to = "model",
               values_to = "pred") %>% 
  mutate(model = case_when(
    model == "RF_pred" ~ "Random Forest",
    model == "XGB_pred" ~ "XGB"
  ))

bbox <- st_bbox(region)
names(bbox) <-  c("left", "bottom", "right", "top")

mapa <- get_stamenmap(bbox, maptype = "toner-background", zoom = 7)

ggplot()+
  geom_sf(data = region1)+
  geom_sf(data = test %>% filter(pred == 1 & provincia == "Misiones"),
          color = "red3",
          size = 0.5)+
  facet_wrap(vars(model))+
  theme_minimal()+
  guides(color = "none")

ggsave("img/10_test_region_misiones.png",
       width = 8,
       height=6)


ggplot()+
  geom_sf(data = region2)+
  geom_sf(data = test %>% filter(pred == 1 & provincia == "Entre Rios"),
          color = "red3",
          size = 0.5)+
  facet_wrap(vars(model))+
  theme_minimal()+
  guides(color = "none")


ggsave("img/11_test_region_entre_rios.png",
       width = 8,
       height=6)
