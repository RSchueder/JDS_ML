# -*- coding: utf-8 -*-
"""
Created on Fri Jul 22 11:13:15 2016

@author: schueder
"""

def read_csv(varagin):
    dat = []
    with open(varagin,'r+') as data:
        page = data.readlines()
        for ii in page:
            tmp = ii.split(";")
            tmp2  = []
            for nn in tmp:
                nn = nn.replace('ÿþ','')
                tmp2.append(nn.replace('\x00',''))    
            if len(tmp2)>1:
                dat.append(tmp2)
    return dat