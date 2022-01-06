#!/usr/bin/env python
# coding: utf-8

# !jupyter nbconvert 20220106_process_number_cases.ipynb --to script

# In[1]:


REFERENCE_FILE = 'electiveactivity_5jan22.csv'

HOLIDAYS_FILE = '20220106_holidays_processed.csv'
YEAR_RANGE = [2021, 2022]

GOVDATA_FILE = 'coronavirus.csv' # download daily

OUTPUT_FILE = '20220106_shiny_ready.csv'

def FORMULA(H__n_of_hospitalCases): # elective surgery rate
    return 0.8412 * ( 0.9852 ** (H__n_of_hospitalCases / 1000) )


# In[2]:


import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import calendar


# In[3]:


df = pd.read_csv(REFERENCE_FILE)
df = df[pd.notnull(df['Month'])]
df['last_date'] = pd.to_datetime(df['Month'], format="%d/%m/%Y")
df['year'] = df['last_date'].dt.year
df['month'] = df['last_date'].dt.month


# In[5]:


dfholidays = pd.read_csv(HOLIDAYS_FILE)
dfholidays['date'] = pd.to_datetime(dfholidays['date']).dt.strftime("%Y-%m-%d") # this will make things easier to process


# In[6]:


dfgov = pd.read_csv(GOVDATA_FILE)
dfgov['date'] = pd.to_datetime(dfgov['date'])


# In[9]:


# get number of working days per month
year_month_working_days = {'year': [],
                           'month': [],
                           'working_days': []}

holidays_processed = 0

for y in range(YEAR_RANGE[0], YEAR_RANGE[1]+1): # only 2021 and 2022
    for m in range(1, 13): # from 1 to 12
        _, e = calendar.monthrange(y, m) # first working day and last day of month
        wd = 0 # number of working days
        for d in pd.date_range(datetime(y, m, 1), datetime(y, m, e)):
            if (d.weekday() <= 4):
                if d.strftime("%Y-%m-%d") in dfholidays['date'].values:
                    holidays_processed += 1
                else:
                    wd += 1
        year_month_working_days['year'].append(y)
        year_month_working_days['month'].append(m)
        year_month_working_days['working_days'].append(wd)
        
assert holidays_processed == dfholidays.shape[0], "There were issues calculating the number of working days in the month, probably code error"

dfworking_days = pd.DataFrame(year_month_working_days)


# In[10]:


df = df.merge(dfworking_days, 
              on=['year', 'month'], how='left')
df['daily_expected'] = df['Expected volume']/df['working_days']


# calculate:
# - percentage reduction in elective
# - drop daily in elective operations
# - running total since December 1st 2021
# - running total since March 1st 2020

# In[11]:


max_surgery = df['last_date'].max()
max_govdata = dfgov['date'].max() ### change


# In[12]:


# cumulative total from df
cum_all = np.sum(df['Drop from expected volume'])
cum_from_december_first = np.sum(df[df['last_date'] >= datetime(2021, 12, 1)]['Drop from expected volume'])

daily_data = {'year': [],
              'month': [],
              'day': [],
              'hosp_days': [],
              'expected_surg_day': [],
              'percent_op': [],
              'percent_op_red': [],
              'daily_cancellations': [],
              'cum_all': [],
              'cum_dec': []}

#cwd = 0 # current working days passed in month
for d in pd.date_range(max_surgery + timedelta(days=1), max_govdata): # this date range is inclusive
    if (d.weekday() <= 4):
        if d.strftime("%Y-%m-%d") in dfholidays['date'].values:
            continue
        else:
            #cwd += 1
           
            # get hospitalisation data from gov file
            assert len(dfgov[dfgov['date'] == d]['hospitalCases'].values) == 1, "Number of coronadata not equal to 1"
            hospitalisations_day = dfgov[dfgov['date'] == d]['hospitalCases'].values[0]
            # expected surgery number daily uses the estimate from previous year!!
            assert len(df[(df['month'] == d.month) & (df['year'] == (d.year - 1))]['daily_expected'].values) == 1, "Number of daily surgeries not equal to 1"
            expected_surgery_day = df[(df['month'] == d.month) & (df['year'] == (d.year - 1))]['daily_expected'].values[0]
            
            # calculate other needed data
            percent_operations = FORMULA(hospitalisations_day)
            percent_reduction_operations = 1 - percent_operations
            daily_rate_cancelations = percent_reduction_operations * expected_surgery_day
            
            cum_all += daily_rate_cancelations
            cum_from_december_first += daily_rate_cancelations
            
            daily_data['year'].append(d.year)
            daily_data['month'].append(d.month)
            daily_data['day'].append(d.day)
            daily_data['hosp_days'].append(hospitalisations_day)
            daily_data['expected_surg_day'].append(expected_surgery_day)
            daily_data['percent_op'].append(percent_operations)
            daily_data['percent_op_red'].append(percent_reduction_operations)
            daily_data['daily_cancellations'].append(daily_rate_cancelations)
            daily_data['cum_all'].append(cum_all)
            daily_data['cum_dec'].append(cum_from_december_first)
            
            
# verify the data
_els = [len(e) for e in daily_data.values()]
for i in _els:
    assert i == max(_els), "number of data elements different in processed data"


# In[13]:


complete_data = pd.DataFrame(daily_data)
complete_data['date'] = complete_data['year'].map(str) + '-' + complete_data['month'].map(str) + '-' + complete_data['day'].map(str)
complete_data['date'] = pd.to_datetime(complete_data['date'], format="%Y-%m-%d")
complete_data['formatted'] = complete_data['date'].dt.strftime('%A, %d %B %Y')


# In[14]:


complete_data.to_csv(OUTPUT_FILE, index=False)

