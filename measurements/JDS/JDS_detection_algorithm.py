# -*- coding: utf-8 -*-
"""
Created on Fri Jan 2017

@author: schueder
JDS sample detection algorithm
SOLUTIONS
author: Rudy Schueder, Deltares
"""
# This script is intended to look at the Joint Danube Survey (JDS) dataset and determine the percentage of samples
# that are below the limit of quantification or detection for each substance across all stations measured in the
# survey. with this information we can determine which substances are worth validating against in the model

# In the excel file JDS_Query met pivot.xls, those measurements that are flagged as below LoQ of LoD obtain "N" for
# "valid measurement", and "Data" becomes the value of the limit below which they reside
# measurements above LoQ get a "Y" for valid measurement
# two pivot tables are made, one for "N" measurements and one for "Y" measurements
# The filters applied to these two pivot tables in JDS_Query met pivot are:
# location codes L,R,M
# fraction analyzed = dissolved, whole water with no separation (both of them)
# all concentrations
# H_Unit = ug/l and mg/l
# Remarks = blank, nothing, PFOS, sample of JDS2
# valid measurement N or Y

# these datafiles are saved as files called valid_binary.csv and invalid_binary.csv and passed to this python program

# the strategy is to first assemble a dictionary of all the substances for which there was ever a measurement taken for
# any of the locations in the JDS.
# This dictionary is derived from 2 csv files that are generated from an xlsx created from the Danube database
# filters were applied to obtain the two csv files as described above
# we first get a list of all substances and a list of all loc ations present in these files
# cycling through each substance, and then location location, if exists a value at that location and substance in the
# valid dictionary, then substance:['',valid measurement,''] for that substance is good (1).
# Else, if a value exists in the invalid dictionary then that value substance:['','',invalid measurement] is bad (0).
# once the dictionary is complete, look through each substance and location:
# substance:['',1,0] is a valid measurement with a value of 1 in the output matrix
# substance:['',1,1] is a valid measurement with a value of 1 in the output matrix
# substance:['',0,1] is an invalid measurement with a value of 0 in the output matrix
# substance:['','',''] is an invalid measurement with a value of '' in the output matrix

# once this has been completed, we want to look at which of those substances
# are valid for value extraction. Those that are will have a value placed at
# each measurement station, and if that station has no valid value, the invalid
# value, which was already determined to be the LoD or the LoQ, will take its
# place

# PLEASE NOTE
# in retrospect, like I now do with the RIVM data, I should have not built the
# script assumung the same JDS stations everywhere, even though this was confirmed
# using more dictionaries could have saved a lot of time and space, learned 
# better for next time! 

import csv
import scipy
from read_csv import read_csv
from read_csv2array import read_csv2array
from isnum import isnum
import numpy as np
import matplotlib
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import date
import pylab
from sklearn import datasets, linear_model

plottrib = 0
file = open('percent_valid.txt','w+')
valid = read_csv("valid_binary.csv")
invalid = read_csv("invalid_binary.csv")
validvalue = read_csv("valid_value.csv")
validarr = read_csv2array("valid_value.csv")
invalidvalue = read_csv("invalid_value.csv")
rivkm = read_csv("MappingJDS_Define.csv")

JDSloc = valid[0][1:-1]
# declare the tributary locations we are not interested in
trib = ['JDS12','JDS16','JDS18','JDS23','JDS29','JDS35','JDS37','JDS41','JDS48','JDS51','JDS54','JDS56','JDS58','JDS63','JDS64']
        
for bb in range(len(JDSloc)):
    JDSloc[bb] = JDSloc[bb].replace('\n','')

valsubs = []
invalsubs = []

# make alist of valid and invalid subs based on what is found in the data
for jj in range(1,len(valid)):
    valsubs.append(valid[jj][0])
for jj in range(1,len(invalid)):
    invalsubs.append(invalid[jj][0])

# ##############################################################################    
# dictionary containing substances, then valid and invalid binary for each loc
# QE is Quality ensured
QE = {} 
# dictionary containing substances, then values for each loc in valid values
# used to 'index-ify' the data for accuracy
VV = {}
# dictionary containing substances, then values for each loc in invalid values
# used to 'index-ify' the data for accuracy
IV = {}
# dictionary containing substances, then the combination of valid values and
# invalid values if there are > 50% valid values
TT = {}
# dictionary containing the coordinates of JDS stations
coord = {}
complyJ = {}
rivkmv = []
# #############################################################################

# find the river kilometer of JDS stations
for rr in rivkm:
    if rr[0] in coord:
        pass
    else:
        if any(rr[0] in ss for ss in JDSloc):
            ind = [s for s in JDSloc if rr[0] == s]    
            try:
                coord[(('%s')%ind[0])] = float(rr[6])
            except:
                pass        

for loc in JDSloc:
    rivkmv.append(coord[loc])     
    
# threshold for a valid location
threshold = 0.5

subs = list(set(valsubs+invalsubs))

for jj in range(1,len(valid)):
    valsubs.append(valid[jj][0])

# cycle through each substance to make a dictionary entry
for jj in subs:
    # index jj in subs is not same in valid or invalid
    QE[(('%s')% jj)] = [] # binary quality
    VV[(('%s')% jj)] = [] # stores valid measurements   
    IV[(('%s')% jj)] = [] # stores invalid measurements
    
    # find substance index for valid substance list
    for gv in valid:
        gmat = 0
        if gv[0] == jj:
            subvalind = valid.index(gv)
            gmat = 1
            break
    # find substance index for invalid substance list
    for bv in invalid:
        bmat = 0
        if bv[0] == jj:
            subinvalind = invalid.index(bv)
            bmat = 1
            break
        
    if gmat == 1 and bmat == 0:
        # value has no bad measurements, need to populate the invalid matrix 
        # for this substance to maintain size
        newline = []
        newline.append(jj)
        for ii in range(len(JDSloc)):
            newline.append(' ')
        invalid.append(newline)
        # make use of the fact that invalid and invalid values have the same 
        # size and structure because they are different ways of representing 
        # the same thing
        invalidvalue.append(newline)

    if gmat == 0 and bmat == 1:
        # value has no good measurements, need to populate the valid matrix for 
        # for this substance to maintain size
        newline = []
        newline.append(jj)
        for ii in range(len(JDSloc)):
            newline.append(' ')
        valid.append(newline)
        validvalue.append(newline)
        
    # when a match was not found, then no index was made for that substance.
    # now that the lists have been appended and a match should be found for all 
    # substances, we need to rerun the substance index search to ensure 
    # completeness
        
    for gv in valid:
        gmat = 0
        if gv[0] == jj:
            subvalind = valid.index(gv)
            gmat = 1
            break
    for bv in invalid:
        bmat = 0
        if bv[0] == jj:
            subinvalind = invalid.index(bv)
            bmat = 1
            break
        
    # cycle through each location for this substance, getting the location 
    # index for the valid and invalid dictionaries. They should be equivalent, 
    # but this is to be sure
    for ll in JDSloc:
        locind = JDSloc.index(ll)
        tmp = []
        tmp.append(ll)
        for gl in valid[0]:
            if gl == ll:
                locvalind = valid[0].index(gl)
                break
        for bl in invalid[0]:
            if bl == ll:
                locinvalind = invalid[0].index(bl) 
                break            
        # check the contents of the cell for this location and substance for presence of valid and or invalid
        # measurements
        if isnum(valid[subvalind][locvalind]):
            if int(valid[subvalind][locvalind]) > 0:
                valval = 1
        else:
            valval = ''
        if isnum(invalid[subinvalind][locinvalind]):
            if int(invalid[subinvalind][locinvalind]) > 0: 
                invalval = 1
        else:
            invalval = ''
            
        VV[(('%s')% jj)].append(validvalue[subvalind][locvalind])
        IV[(('%s')% jj)].append(invalidvalue[subinvalind][locinvalind])
        tmp.append(valval)  
        tmp.append(invalval)
        QE[(('%s')% jj)].append(tmp)

# #############################################################################
# now that the dictionary of substance:[Loc,valid binary,invalid binary] has 
# been made, we write it to the matrix of 0 and 1 , and we also want to make a
# new data structure that contains all of the values for these valid substances,
# with stations with invalid data populated by the associated limit
# #############################################################################

# write the header
comMat = []
file.write(" ;")
for ll in JDSloc:
    file.write(("%s;")%ll)
file.write("\n")
cc = 0

for sub in subs:
    file.write(("%s;")%sub)
    gg = 0
    presentLoc = []
    for loc in QE[(('%s')% sub)]:
        if loc[0] not in trib:
            # this next algorith needs to check for 0 values
            if loc[1] == 1:
                # this means there is a valid measurement
                file.write("1;")
                gg = gg + 1
                presentLoc.append(loc[0])
            elif loc[2] == 1 and loc[1] != 1:
                # there is an invalid measurement and no valid measurement
                file.write("0;")
                presentLoc.append(loc[0])
            else:
                # there is no measurement
                pass            
            # no measurement does not add to to the total measurement number
            # that means the data needs to be plotted against a subset of the
            # JDS data. presentLoc should contain only non-tributaries where
            # real measurements were made for that substance. 
    file.write(("%s\n")% str(gg/len(presentLoc)))

    # the precent valid has now been calculated
# #############################################################################
    # now to make a dictionary of the compliant substances. where we replace
    # the zero values with
    if gg/len(presentLoc) >= threshold:
        TT[(('%s')%sub)] = []
        complyJ[(('%s')%sub)] = gg/len(presentLoc)
        for loc in presentLoc:
            # Take the measured value and when not possible take the limit, 
            # assuming the limit is valid since < 50% are missing data
            try:
                # value from valid data
                tmp = float(VV[(('%s')% sub)][JDSloc.index(loc)])
            except:
                try:
                    # value from invalid data
                    tmp = float(IV[(('%s')% sub)][JDSloc.index(loc)])
                except:
                    # no data available
                    pass
                    # This means that there was no measurement in the valid or 
                    # invalid, which is not impossible but should not be common
            if isnum(tmp):
                TT[(('%s')%sub)].append(tmp)
            if tmp == 0:
                pass
                
        # NOW DO SOME LINEAR REGRESSION!       
        regr = linear_model.LinearRegression()
        # this is valid because TT was appended in the order of presentLoc, 
        # which we are looping through
        rivkmv = []
        rivdat = []
        for loc in presentLoc:
            rivkmv.append(coord[loc])
        rivkmv = np.array(rivkmv)
        siz = len(rivkmv)
        km = -rivkmv.reshape(siz,1)
        rivdat = np.array(TT[(('%s')%sub)])
        siz = len(rivdat)
        dat = rivdat.reshape(siz,1)
        rivl = []
        locmask = []
      
        tmp1 = []
        tmp2 = []
        
        regr.fit(km,dat)
        slope, intercept, r_value, p_value, std_err = scipy.stats.mstats.linregress(km, dat)        
        
        # PLOT       
        lastplotted = sub
        fig = plt.figure(cc)
        ax = fig.add_subplot(1,1,1)
        cc = cc + 1    
        figure = plt.gcf()
        figure.set_size_inches(16,12)
        fig.suptitle((('%s')% sub))        
        dot = plt.plot(-rivkmv,TT[(('%s')%sub)],'ok')
        #plt.plot(np.unique(km), np.poly1d(np.polyfit(km, dat, 1))(np.unique(km)))
        lin = plt.plot(km,regr.predict(km), color = 'blue',linewidth=2)
        plt.legend((sub,('R2 = %.2f - %s samples')% (r_value**2,str(len(km)))))
        plt.xlabel('distance from river mouth [km]')
        plt.ylabel('concentration [ug/l]')

        pylab.savefig((('longitudinal\\%s.png') % sub), dpi = 200)
        plt.close('all')

