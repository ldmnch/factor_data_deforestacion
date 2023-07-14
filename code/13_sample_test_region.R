library(tidyverse)
library(purrr)
library(sf)
library(sp)

region <- st_read("data/otbn/otbn_misiones.geojson")

sample_points <- st_sample(region, size = 3000, "random")

sample <- st_as_sf(sample_points) %>%
  rename(geometry = x) %>%
  mutate(provincia = "Misiones")

sample <- st_transform(sample, crs = "WGS84") 

st_write(sample, "data/test_region/points_misiones.geojson", append = F)
