'''
create data table based on query from substance property database
'''

from produce_data import main
import pandas as pd

props = ['log Kow', 'Ks']
df_all = pd.DataFrame()

for prop in props:
    df = main(prop)
    df.dropna(axis = 0, inplace = True)
    df = df[['SMILES', 'value']]
    df.rename(columns = {'SMILES': 'smiles', 'value' : prop}, inplace = True)
    df_all = pd.concat([df_all, df], axis = 1, ignore_index = False)

df_all.to_csv(r'validation_data\SOLUTIONS_properties.csv')
