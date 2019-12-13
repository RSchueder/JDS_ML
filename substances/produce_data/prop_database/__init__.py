
import sqlite3
import pandas as pd 
import numpy as np
import os

db_path = os.path.dirname(os.path.abspath(__file__)) + '\\' + 'substance_properties.db'
print(db_path)
conn = sqlite3.connect((db_path))
c = conn.cursor()

def clean_vals(x):
    try:
        return float(x)
    except:
        return np.nan
    
    
def substance_list():
    '''
    returns a list of all known substances
    '''
    c.execute("SELECT CAS FROM substances")
    dat = c.fetchall()

    return dat    


def request_substance(CAS = None):
    '''
    retrieves property information data from database 
    '''   
    c.execute("PRAGMA table_info(substances)")
    cols = c.fetchall()
    if CAS is None:
        c.execute("SELECT * FROM substances ")
    else:        
        c.execute("SELECT * FROM substances WHERE CAS = '{qq}' ".format(qq =  CAS))
    dat = c.fetchall()
    
    return cols, dat    


def request_substance_pd(CAS = None):
    '''
    retrieves property information data from database using pandas.read_sql
    '''   

    if CAS is None:
        dat = pd.read_sql("SELECT * FROM substances ", conn)
    else:        
        dat = pd.read_sql("SELECT * FROM substances WHERE CAS = '{qq}' ".format(qq =  CAS), conn)
    
    return dat 


def request_property(prop, CAS = None):
    '''
    retrieves cleaned data from database 
    '''    
    c.execute("PRAGMA table_info(substance_properties)")
    cols = c.fetchall()
    if CAS is None:
        c.execute("SELECT * FROM substance_properties WHERE property = '{pp}'".format(pp = prop.replace("'","''")))    
    else:
    
        c.execute("SELECT * FROM substance_properties WHERE CAS = '{qq}' AND property = '{pp}'".format(qq =  CAS, pp = prop.replace("'","''")))
    dat = c.fetchall()

    return cols, dat


def request_property_pd(prop, CAS = None):
    '''
    retrieves cleaned data from database 
    '''    

    if CAS is None:
        dat = pd.read_sql("SELECT * FROM substance_properties WHERE property = '{pp}'".format(pp = prop.replace("'","''")), conn)
    else:    
        dat = pd.read_sql("SELECT * FROM substance_properties WHERE CAS = '{qq}' AND property = '{pp}'".format(qq =  CAS, pp = prop.replace("'","''")), conn)
    
    df = dat[['CAS','value']].copy()
    df['value'] = df['value'].copy().apply(clean_vals)
    df.dropna()
    
    return df.groupby(['CAS']).mean()

