library(tidyverse)
library(sf)

paths <- list.files(path = "./data/ndvi_points_years_0123",
           pattern = "*.geojson") 

paths <- paste0("./data/ndvi_points_years_0123/", paths)

train_paths <- paths[str_detect(paths, 'train')]
test_paths <- paths[str_detect(paths, 'test')]

train_sets <- lapply(train_paths, st_read)

train_sets <- train_sets %>% reduce(st_join)

train_sets <- train_sets %>% select(starts_with("NDVI_"), id.x, label.x, -NDVI_2018.x) %>%
  rename(NDVI_2018 = NDVI_2018.y)

test_sets <- lapply(test_paths, st_read)

test_sets <- test_sets %>% reduce(st_join)

test_sets <- test_sets %>% select(starts_with("NDVI_"), id.x, label.x, -NDVI_2018.x) %>%
  rename(NDVI_2018 = NDVI_2018.y)

st_write(train_sets, "./data/train_0123.geojson")
st_write(test_sets, "./data/test_0123.geojson")
