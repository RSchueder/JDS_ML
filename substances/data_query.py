'''
create data table based on query from substance property database
'''

from produce_data import main
import pandas as pd

props = ['log Kow', 'Ks', 'Molar mass [Da]', 'Kbiodeg [1/s]']
df_all = pd.DataFrame()

if len(props) >= 1:

    df = main(props[0])
    df.dropna(axis = 0, inplace = True)
    df = df[['SMILES']]
    df.rename(columns = {'SMILES': 'smiles'}, inplace = True)
    df_all = pd.concat([df_all, df], axis = 1, ignore_index = False)

    for prop in props:
        df = main(prop)
        df.dropna(axis = 0, inplace = True)
        df = df[['value']]
        df.rename(columns = {'value' : prop}, inplace = True)
        df_all = pd.concat([df_all, df], axis = 1, ignore_index = False)

    df_all.dropna(axis = 0, inplace = True)
    df_all.to_csv(r'validation_data\SOLUTIONS_properties.csv')
else:
    print("No properties provided, process aborted")
