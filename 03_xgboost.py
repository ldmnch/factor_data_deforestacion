#!/usr/bin/env python
# coding: utf-8

# In[ ]:


from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report
from sklearn.pipeline import Pipeline
from sklearn.model_selection import GridSearchCV, KFold
from sklearn.preprocessing import StandardScaler
from joblib import dump, load
import geopandas as gpd
import xgboost as xgb
import pandas as pd


# In[ ]:


train = gpd.read_file( "./data/train_data_final.geojson")
test =  gpd.read_file("./data/test_data_final.geojson")


# In[ ]:


X_train = train.loc[:,'NDVI_2000':'NDVI_2019']
y_train = train['label_0']
X_test = test.loc[:,'NDVI_2000':'NDVI_2019']
y_test = test['label_0']


# In[ ]:


pipe = Pipeline(
    [
        ('preproc_scaling', StandardScaler()),
        ('xgboost', xgb.XGBClassifier(n_jobs=16))
    
    ])


# In[ ]:


params = {"xgboost__objective":["multi:softprob"],
          "xgboost__learning_rate": [0.1, 0.01, 0.001],
          "xgboost__max_depth": [2, 5, 10],
          "xgboost__n_estimators":[1000]} 


# In[ ]:


grid_search = GridSearchCV(pipe,
                   params,
                   verbose=1, 
                   n_jobs=16, 
                   cv=KFold(n_splits=5, shuffle=True, random_state=123),
                  )


# In[ ]:


grid_search.fit(X_train, y_train)


# In[ ]:


y_pred = grid_search.predict(X_test)


# In[ ]:


print(classification_report(y_test, y_pred))


# In[ ]:


dump(grid_search, './models/cv_xgb.joblib') 


# In[ ]:




