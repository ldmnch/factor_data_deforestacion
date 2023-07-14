import geopandas as gpd
import os
import glob
import pandas as pd
from functools import reduce
import ee
import geemap.foliumap as geemap
import json
import os
import numpy as np
import time
from math import sqrt
from joblib import dump, load

def geojson2FeatureCollection(path_file='/content/drive/MyDrive/fundar_deforestacion/ecoregiones/chaco_seco.geojson'):
  with open(path_file) as f:
    json_data = json.load(f)
  return(ee.FeatureCollection(json_data))


def exporto_modis_train_test(area,
                  rango_anios = range(0, 4, 1),
                  file_sufix = "00-03"):
    
    modis = ee.ImageCollection("MODIS/MOD09GA_006_NDVI")

    lista_modis = []
    
    for i in rango_anios:
        
        if i < 10:
            selec_modis = modis.filterBounds(area).filterDate('200'+str(i)+'-01-01', '200'+str(i)+'-12-30').select('NDVI')
            selec_modis = selec_modis.median().rename('NDVI_200'+str(i)).clip(area)
            lista_modis.append(selec_modis)


        elif i>=10:
            selec_modis = modis.filterBounds(area).filterDate('20'+str(i)+'-01-01', '20'+str(i)+'-12-30').select('NDVI')
            selec_modis = selec_modis.median().rename('NDVI_20'+str(i)).clip(area)
            lista_modis.append(selec_modis)

    modis_filtrada = lista_modis[0]

    for images in lista_modis[1:]:
        modis_filtrada = modis_filtrada.addBands(images)
  
    training = modis_filtrada.sampleRegions(**{
              'collection': train_set,
              'properties': ['label'],
              'scale': 250,
              'geometries':True
            })
  
    task_train = ee.batch.Export.table.toDrive(**{
          'collection': training,
          'description': 'ndvi_train_set_'+file_sufix,
          'folder':'fundar_deforestacion_input_230123',
          'fileFormat': 'GeoJSON' })
          
    task_train.start()

    testing = modis_filtrada.sampleRegions(**{
              'collection': test_set,
              'properties': ['label'],
              'scale': 250,
              'geometries':True
            })

    task_test = ee.batch.Export.table.toDrive(**{
          'collection': testing,
          'description': 'ndvi_test_set_'+file_sufix,
          'folder':'fundar_deforestacion_input_230123',
          'fileFormat': 'GeoJSON' })
          
    task_test.start()

    print("Exportando train y test de los años "+file_sufix)
    

def generate_train_test(path = './data/ndvi_points_years/*.geojson'):
    
    paths = glob.glob(path)
    
    print(paths)
    
    for split in ['train', 'test']:
        
        print(split)
        
        paths_split = [x for x in paths if split in x]
               
        sets = [gpd.read_file(x) for x in paths_split]
        sets = gpd.GeoDataFrame(reduce(lambda df1, df2: df1.merge(df2, "inner"), sets))
        
        sets = sets.reindex(sorted(sets.columns), axis=1)
                
        sets.to_file('/content/drive/MyDrive/deforestation_input/'+split+'_data_final.geojson', 
                     driver='GeoJSON')      
        

def define_final_model(pipeline, model_name):
    
    year_features = ["year_"+str(i) for i in range(0,20)]
    
    pipeline.feature_names_in_ = np.array(year_features)
    best_model = pipeline.best_estimator_

    dumpsets = sets.sort_index(axis=1)

new_column_names = ["year_" + str(i) for i in range(0, 20)]
sets = sets.rename(columns=dict(zip(sets.columns[:20], new_column_names)))
(pipeline, '../models/'+model_name+'.joblib') 
    
def run_predictions(table_ndvi,
                    model = ['RF', 'XGB', 'both']):
    
    data =  gpd.read_file(table_ndvi)
    
    NDVI = data.loc[:,'year_0':'year_19']
    
    if model == "RF":
        
        pipe = load('../models/cv_rf.joblib') 
        
        pipe = pipe.best_estimator_
        
        pred = pipe.predict(NDVI)
        
        data['RF_pred'] = pred
        
    elif model == "XGB": 
        
        pipe = load('../models/cv_xgb_2.joblib') 
        
        pipe = pipe.best_estimator_
        
        pred = pipe.predict(NDVI)
        
        data['XGB_pred'] = pred
    
    elif model == "both":
        
        pipe_rf = load('../models/cv_rf.joblib') 
        pipe_xgb = load('../models/cv_xgb_2.joblib') 
        
        pipe_rf = pipe_rf.best_estimator_
        pipe_xgb = pipe_xgb.best_estimator_
        
        pred_RF = pipe_rf.predict(NDVI)
        pred_XGB = pipe_xgb.predict(NDVI)
        
        data['RF_pred'] = pred_RF
        data['XGB_pred'] = pred_XGB
        
        
    return(data)

def proc_data(path = './data/test_region/*.geojson',
              path_output = './data/test_region/data_final.geojson'):

    paths = glob.glob(path)

    print(paths)

    paths_split = [x for x in paths]

    sets = [gpd.read_file(x) for x in paths_split]
    sets = gpd.GeoDataFrame(reduce(lambda df1, df2: df1.merge(df2, "inner"), sets))

    sets = sets.reindex(sorted(sets.columns), axis=1)

    new_column_names = ["year_" + str(i) for i in range(0, 20)]
    sets = sets.rename(columns=dict(zip(sets.columns[:20], new_column_names)))


    sets.to_file(path_output, 
                     driver='GeoJSON')      
    
def exporto_modis(area,
                  rango_anios = range(0, 4, 1),
                  file_sufix = "00-03"):

    modis = ee.ImageCollection("MODIS/MOD09GA_006_NDVI")

    lista_modis = []

    for i in rango_anios:

        if i < 10:

            selec_modis = modis.filterBounds(area).filterDate('200'+str(i)+'-01-01', '200'+str(i)+'-12-30').select('NDVI')
            selec_modis = selec_modis.median().rename('NDVI_200'+str(i)).clip(area)
            lista_modis.append(selec_modis)


        elif i>=10:

            selec_modis = modis.filterBounds(area).filterDate('20'+str(i)+'-01-01', '20'+str(i)+'-12-30').select('NDVI')
            selec_modis = selec_modis.median().rename('NDVI_20'+str(i)).clip(area)
            lista_modis.append(selec_modis)

    modis_filtrada = lista_modis[0]

    for images in lista_modis[1:]:

        modis_filtrada = modis_filtrada.addBands(images)


    region_sample = modis_filtrada.sampleRegions(**{
              'collection': area,
              #'properties': ['label'],
              'scale': 250,
              'geometries':True
            })

    task_train = ee.batch.Export.table.toDrive(**{
          'collection': region_sample,
          'description': 'ndvi_model_'+file_sufix,
          'folder':'deforestation_input_new',
          'fileFormat': 'GeoJSON' })

    task_train.start()

    print("Exporto MODIS "+file_sufix)
