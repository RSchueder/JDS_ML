
import produce_data.prop_database as db
import pandas as pd 
import numpy as np
import datetime
    
def main(prop):
    '''
    produce data table based on query property
    '''
    
    subs = db.request_substance_pd()
    subs.dropna(axis = 0, inplace = True)
    subs.set_index('CAS', inplace = True)
    subs = subs[~subs.index.duplicated(keep='first')]

    val = db.request_property_pd(prop)
    
    df = pd.concat([subs, val], axis = 1, ignore_index = False)
    
    return df


def get_col_index(search_name, cols):
    '''
    get index in sql return for desired column name
    '''
    for c_ind, col in enumerate(cols):
        name = col[1]
        if name == search_name:
            p_ind = c_ind
    
    return p_ind
            

def average_property(data, ind):
    '''
    returns average value of multiple value property
    '''
    arr = list()
    for row in data:
        val = row[ind]
        try:
            arr.append(float(val))
        except:
            pass
        
    return np.nanmean(np.array(arr))

    
def main_old(prop):
    '''
    produce data table based on query property
    '''
    # first method tried, slow but works, keep for reference
    substances = db.substance_list()
    CAS = substances[0][0]
    print(CAS)
    sub_cols,  info = db.request_substance(CAS)
    prop_cols, data = db.request_property(substances[0][0], prop)
    prop_ind = get_col_index('value', prop_cols)
    
    table = list()
    for sub in substances:
        CAS = sub[0]
        
        #st = datetime.datetime.now()
        sub_cols,  info = db.request_substance(CAS)
        #et = datetime.datetime.now()
        #print('step 1 took '  + str((et-st).microseconds/1000))
        
        #st = datetime.datetime.now()
        prop_cols, data = db.request_property(prop, CAS)
        val = average_property(data, prop_ind)
        #et = datetime.datetime.now()
        #print('step 2 took '  + str((et-st).microseconds/1000))
        
        #st = datetime.datetime.now()
        entry = [info[0][ii] for ii in range(0, len(info[0]))] + ['%.3f' % val]
        table.append(entry)
        #et = datetime.datetime.now()
        #print('step 3 took '  + str((et-st).microseconds/1000))
        
        print(CAS)


    cols = [sub_cols[ii][1] for ii in range(0, len(sub_cols))]
    cols.append(prop)
    df = pd.DataFrame(table, columns = cols)
    
    return df


