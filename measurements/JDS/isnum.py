# -*- coding: utf-8 -*-
"""
Created on Thu Jul 21 17:54:00 2016

@author: schueder
"""

def isnum(varagin):
    try:                    
        float(varagin)
        return True
    except ValueError:
        return False