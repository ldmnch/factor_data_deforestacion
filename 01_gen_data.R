library(tidyverse)
library(sf)

paths <- list.files(path = "./data/ndvi_anios",
           pattern = "*.csv") 

paths <- paste0("./data/ndvi_anios/", paths)

train_paths <- paths[str_detect(paths, 'train')]
test_paths <- paths[str_detect(paths, 'test')]

train_sets <- lapply(train_paths, read_csv)

train_sets <- train_sets %>% reduce(inner_join, by = ".geo")
