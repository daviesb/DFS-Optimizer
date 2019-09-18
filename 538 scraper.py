# -*- coding: utf-8 -*-
"""
Created on Sat Aug 24 23:16:05 2019

@author: daviesb
"""

import requests
from bs4 import BeautifulSoup as bs
import pandas as pd

team_list = ['76ers',
             'bucks',
             'bulls',
             'cavaliers',
             'celtics',
             'clippers',
             'grizzlies',
             'hawks',
             'heat',
             'hornets',
             'jazz',
             'kings',
             'knicks',
             'lakers',
             'magic',
             'mavericks',
             'nets',
             'nuggets',
             'pacers',
             'pelicans',
             'pistons',
             'raptors',
             'rockets',
             'spurs',
             'suns',
             'thunder',
             'timberwolves',
             'trail-blazers',
             'warriors',
             'wizards']

df_total = pd.DataFrame(columns = ['name',
                                  'PG',
                                  'SG',
                                  'SF',
                                  'PF',
                                  'C',
                                  'Total',
                                  'vs Full Strength',
                                  'off rat',
                                  'def rat'])

for team in team_list:

    url = str('https://projects.fivethirtyeight.com/2020-nba-predictions/' + team)
    response = requests.get(url)
    
    soup = bs(response.text, 'html.parser')
    table = soup.find_all('div', id='current')
    #print(soup.prettify())
    
    df = pd.read_html(str(table))[0]
    
    df.drop(df.tail(3).index, inplace=True)
    df.drop(df.columns[1], axis=1, inplace=True)
    df.drop(df.columns[8:11], axis=1, inplace=True)
    df.drop(df.columns[10:14], axis=1, inplace=True)
    
    df.columns = ['name',
                  'PG',
                  'SG',
                  'SF',
                  'PF',
                  'C',
                  'Total',
                  'vs Full Strength',
                  'off rat',
                  'def rat']

    df_total = df_total.append(df, ignore_index=True)
    
cols = [1, 2, 3, 4, 5, 6]
df_total.iloc[:, cols] = df_total.iloc[:, cols].apply(pd.to_numeric)
