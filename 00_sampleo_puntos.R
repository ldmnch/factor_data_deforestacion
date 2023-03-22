library(tidyverse)
library(purrr)
library(sf)
library(sp)

data <- st_read('./data/training_polygons.geojson')

lista_puntos <- list()

sampleo_puntos <- function(etiqueta){
  
  subset <- data %>% filter(label == etiqueta)
  
  geometry <- st_sample(subset, size = 3000, "random")
  
  puntos_geometry <- st_sf(geometry)
  
  puntos_geometry$label <- etiqueta
  
  lista_puntos <- append(lista_puntos, puntos_geometry)
  
  return(puntos_geometry)
}

listado_dfs <- map(unique(data$label), sampleo_puntos)

data <- bind_rows(listado_dfs)

data$id <- 1:nrow(data)

train_data <- data %>% group_by(label) %>% slice_sample(prop = 0.7)

test_data <- data %>% slice(-pull(train_data,id))

st_write(train_data, "/home/laia/Escritorio/factor_data/deforestacion_montes/data/training_data.geojson")
st_write(test_data, "/home/laia/Escritorio/factor_data/deforestacion_montes/data/test_data.geojson")
