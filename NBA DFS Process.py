# -*- coding: utf-8 -*-
"""
Created on Mon Oct 21 19:58:48 2019

@author: daviesb
"""

#%% packages
import pandas as pd
import requests
from bs4 import BeautifulSoup as bs
import numpy as np
import re
from datetime import date
import unidecode

#%% init vars
gamelogs_refresh = False  ### if you want to refresh 2020 gamelogs, change to True
FPPP_weights = [0, 0.2, 0.8] # 2018, 2019, 2020 FPP 100 possession weights
Pace_weights = [0, 0, 1] # 2018, 2019, 2020
SD_weights = [0.1, 0.4, 0.5] # 2018, 2019, 2020
Minute_weights = [0.6, 0, 0.4] ### BBM, 538, DFN
Proj_weights = [0.4, 0.4, 0.2] ### BBM, BD, DFN
SD_Regress_weights = [2/3, 1/3] ### weight of calculated SD, and weight of regression factor
DvP_Regress_weight = 0.8

### 2020 data thresholds
min_minutes = 100 ### minimum number of minutes played in 2020 to factor into BD Proj
min_games_SD = 10


#%% Import BBM data

BBM_filename = r'C:\Users\daviesb\Desktop\NBA\2019-2020\BBM\DFS_' + date.today().strftime('%Y_%m_%d') + '.xls'
df_BBM = pd.read_excel(BBM_filename)
df_agg = df_BBM[['Name', 'Price', 'Team', 'Pos', 'Opp', 'm/g', 'Value']]
df_agg.rename(columns={'m/g':'BBM Mins', 'Value':'BBM Proj', 'Team':'Abbr'}, inplace=True)
df_agg['Home'] = np.where(df_agg.Opp.str[:1] == '@', -0.5, 0.5)
df_agg.Name.replace({'O.G. Anunoby':'OG Anunoby',
                     'J.J. Redick':'JJ Redick',
                     'Moe Harkless':'Maurice Harkless',
                     'Jaren Jackson Jr.':'Jaren Jackson',
                     'Tim Hardaway Jr.':'Tim Hardaway',
                     'Larry Nance Jr.':'Larry Nance',
                     'Glenn Robinson III':'Glenn Robinson',
                     'R.J. Barrett':'RJ Barrett',
                     'Troy Brown Jr':'Troy Brown',
                     'Mohamed Bamba':'Mo Bamba',
                     'Wendell Carter Jr.':'Wendell Carter',
                     'PJ Washington':'P.J. Washington', 
                     'C.J. McCollum':'CJ McCollum',
                     'Kelly Oubre Jr.':'Kelly Oubre',
                     'Shaq Harrison':'Shaquille Harrison',
                     'Dennis Smith Jr.':'Dennis Smith',
                     'Michael Porter Jr.':'Michael Porter',
                     'Ty Wallace':'Tyrone Wallace',
                     'Marvin Bagley III':'Marvin Bagley',
                     'Juan Hernangomez':'Juancho Hernangomez',
                     'Lonnie Walker IV':'Lonnie Walker',
                     'Gary Trent Jr.':'Gary Trent',
                     'Derrick Walton Jr.':'Derrick Walton'}, inplace=True)

### list of team matchups needed for possession calculations later
df_matchups = df_agg[['Abbr', 'Opp']]
df_matchups['Opp'] = df_matchups['Opp'].map(lambda x: x.lstrip('@ '))
df_matchups = df_matchups.drop_duplicates()


#%% Import DFN Projection data

DFN_filename = r'C:\Users\daviesb\Desktop\NBA\2019-2020\DFN\DFN NBA FD ' + date.today().strftime('%#m_%#d') + '.csv'
df_DFN = pd.read_csv(DFN_filename).rename(columns={'Player Name':'Name', 'Proj Min':'DFN Min', 'Proj FP':'DFN Proj'})

df_DFN.Name.replace({'Wendell Carter Jr.':'Wendell Carter',
                      'Tim Hardaway Jr.':'Tim Hardaway',
                      'Kevin Porter Jr.':'Kevin Porter',
                      'Dennis Smith Jr.':'Dennis Smith',
                      'C.J. McCollum':'CJ McCollum',
                      'Glenn Robinson III':'Glenn Robinson',
                      'Taurean Waller-Prince':'Taurean Prince',
                      'J.J. Redick':'JJ Redick',
                      'Brad Beal':'Bradley Beal',
                      'Ishmael Smith':'Ish Smith',
                      'Dave Bertans':'Davis Bertans',
                      'Louis Williams':'Lou Williams',
                      'Domas Sabonis':'Domantas Sabonis',
                      'R.J. Barrett':'RJ Barrett',
                      'Fred Van Vleet':'Fred VanVleet',
                      'O.G. Anunoby':'OG Anunoby',
                      'DeAndre Bembry':"DeAndre' Bembry",
                      'PJ Washington':'P.J. Washington',
                      'Patrick Mills':'Patty Mills',
                      'Juan Hernangomez':'Juancho Hernangomez',
                      'Derrick Jones Jr.':'Derrick Jones',
                      'Jose Juan Barea':'J.J. Barea',
                      'Patrick Mccaw':'Patrick McCaw',
                      'Larry Nance Jr.':'Larry Nance',
                      'Mohamed Bamba':'Mo Bamba',
                      'Timothe Luwawu':'Timothe Luwawu-Cabarrot',
                      'Derrick Walton Jr.':'Derrick Walton'}, inplace=True)


#%% Scrape 2019-2020 gamelogs

if gamelogs_refresh == False:
    df_gamelogs = pd.read_excel(r'C:\Users\daviesb\Desktop\NBA\2019-2020\gamelogs_2020.xlsx')
    
else:

    df_players = pd.read_excel(r'C:\Users\daviesb\Desktop\NBA\2019-2020\Player List 2020.xlsx', usecols='G:H')
    missing_record = []
    
    df_gamelogs = pd.DataFrame(columns = ['Rk','G','Date','Age','Tm','Unnamed: 5','Opp','Unnamed: 7','GS','MP','FG','FGA','FG%','3P','3PA','3P%',
                                      'FT','FTA','FT%','ORB','DRB','TRB','AST','STL','BLK','TOV','PF','PTS','GmSc','+/-','Unnamed: 30','Player Name'])
    
    for url, player in zip(df_players['url'], df_players['Player Name']):
        try:
            response = requests.get(url)
            soup = bs(response.text, 'html.parser')
            table = soup.find('table', id='pgl_basic')
            df = pd.read_html(str(table))[0]
            df['Player Name'] = player
            df_gamelogs = df_gamelogs.append(df)
        except:
            missing_record.append(player)
            
            
    df_gamelogs = df_gamelogs[df_gamelogs['AST'] != 'AST']
    df_gamelogs = df_gamelogs[df_gamelogs['AST'] != 'Inactive']
    df_gamelogs = df_gamelogs[df_gamelogs['AST'] != 'Did Not Play']
    df_gamelogs = df_gamelogs[df_gamelogs['AST'] != 'Did Not Dress']
    df_gamelogs = df_gamelogs[df_gamelogs['AST'] != 'Not With Team']
    df_gamelogs = df_gamelogs[df_gamelogs['AST'] != 'Player Suspended']
    df_gamelogs.drop(['Unnamed: 22', 'Unnamed: 23', 'Unnamed: 24', 'Unnamed: 25', 'Unnamed: 26','Unnamed: 27', 'Unnamed: 28', \
                      'Unnamed: 29', 'Unnamed: 30'], axis=1, inplace=True)
    
    df_gamelogs.rename(columns = {'Unnamed: 5':'Home', 'Unnamed: 7':'Result', 'Player Name':'Name'}, inplace=True)
    
    df_gamelogs['AST'] = pd.to_numeric(df_gamelogs['AST'])
    df_gamelogs['BLK'] = pd.to_numeric(df_gamelogs['BLK'])
    df_gamelogs['PTS'] = pd.to_numeric(df_gamelogs['PTS'])
    df_gamelogs['STL'] = pd.to_numeric(df_gamelogs['STL'])
    df_gamelogs['TRB'] = pd.to_numeric(df_gamelogs['TRB'])
    df_gamelogs['TOV'] = pd.to_numeric(df_gamelogs['TOV'])
    
    
    df_gamelogs['Mins'] = df_gamelogs['MP'].str.split(':').apply(lambda x: int(x[0]) + int(x[1]) / 60)
    df_gamelogs['FP'] = df_gamelogs['AST']*1.5 + df_gamelogs['BLK']*3 + df_gamelogs['PTS'] + df_gamelogs['STL']*3 \
                        + df_gamelogs['TRB']*1.2 - df_gamelogs['TOV']
    df_gamelogs['FP/Min'] = np.where(df_gamelogs.Mins >= 20, df_gamelogs.FP / df_gamelogs.Mins, '')
    df_gamelogs['FP/Min'] = pd.to_numeric(df_gamelogs['FP/Min'])   
    
    df_gamelogs.to_excel(r'C:\Users\daviesb\Desktop\NBA\2019-2020\gamelogs_2020.xlsx')

df_gamelogs = df_gamelogs[df_gamelogs['Mins'] >= 20]
df_gl_count = df_gamelogs.groupby('Name')['FP/Min'].count().reset_index().rename(columns={'FP/Min':'Count'})
df_gamelogs = pd.merge(df_gamelogs, df_gl_count, on='Name', how='left')
df_gamelogs = df_gamelogs.loc[df_gamelogs['Count'] >= min_games_SD]
df_SD_2020 = df_gamelogs.groupby('Name')['FP/Min'].std().reset_index().rename(columns={'FP/Min':'SD_2020'})
df_SD_2020.Name.replace({'O.G. Anunoby':'OG Anunoby',
                         'J.J. Redick':'JJ Redick',
                         'Moe Harkless':'Maurice Harkless',
                         'Jaren Jackson Jr.':'Jaren Jackson',
                         'PJ Washington':'P.J. Washington',
                         'Kelly Oubre Jr.':'Kelly Oubre',
                         'Danuel House Jr.':'Danuel House',
                         'Glenn Robinson III':'Glenn Robinson',
                         'James Ennis III':'James Ennis',
                         'Larry Nance Jr.':'Larry Nance',
                         'Marvin Bagley III':'Marvin Bagley',
                         'Otto Porter Jr.':'Otto Porter',
                         'Robert Williams III':'Robert Williams',
                         'Tim Hardaway Jr.':'Tim Hardaway',
                         'Wendell Carter Jr.':'Wendell Carter',
                         'Troy Brown Jr.':'Troy Brown',
                         'PJ Tucker':'P.J. Tucker',
                         'Cameron Reddish':'Cam Reddish',
                         'Michael Porter Jr.':'Michael Porter',
                         'Derrick Jones Jr.':'Derrick Jones',
                         'JJ Barea':'J.J. Barea',
                         'Lonnie Walker IV':'Lonnie Walker'}, inplace=True)


#%% Scrape 2019-2020 Player and Team Possession Data

### Player Poss
url = "https://www.basketball-reference.com/leagues/NBA_2020_per_poss.html"
response = requests.get(url)
soup = bs(response.text, 'html.parser')
table = soup.find('table', id='per_poss_stats')
df_player_poss = pd.read_html(str(table))[0]

df_player_poss = df_player_poss[df_player_poss['AST'] != 'AST']

df_player_poss['count'] = df_player_poss.groupby('Player').cumcount() + 1
df_player_poss = df_player_poss[df_player_poss['count'] == 1]
df_player_poss['Player'] = df_player_poss['Player'].apply(unidecode.unidecode)

for col in ['PTS', 'BLK', 'STL', 'TRB', 'AST', 'TOV']:
    df_player_poss[col] = df_player_poss[col].astype('float')

df_player_poss['FPPP_2020'] = df_player_poss['PTS'] + df_player_poss['BLK']*3 + df_player_poss['STL']*3 + df_player_poss['AST']*1.5 + \
                            df_player_poss['TRB']*1.2 - df_player_poss['TOV']

df_player_poss['MP'] = df_player_poss['MP'].astype(float)
df_player_poss['FPPP_2020'] = np.where(df_player_poss['MP'] < min_minutes, None, df_player_poss['FPPP_2020']).astype(float)

                            
df_player_poss.rename(columns={'Player':'Name'}, inplace=True)
df_player_poss.Name.replace({'Taurean Waller-Prince':'Taurean Prince',
                             'Nicolò Melli':'Nicolo Melli',
                             'PJ Washington':'P.J. Washington',
                             'Jakob Poltl':'Jakob Poeltl',
                             'J.J. Redick':'JJ Redick',
                             'Juan Hernangomez':'Juancho Hernangomez'}, inplace=True)                            
                            
### Team Poss
url_team = 'https://www.basketball-reference.com/leagues/NBA_2020.html'
html = requests.get(url_team).content.decode()
bsObj = bs(re.sub("<!--|-->", "", html), "lxml")
table = bsObj.find('table', id='misc_stats')
df_team_2020 = pd.read_html(str(table))[0]
df_team_2020 = df_team_2020.iloc[:, [1, 13]]
df_team_2020.columns = ['Team', 'Pace_2020']
df_team_2020['Team'] = df_team_2020['Team'].map(lambda x: x.rstrip('*'))                        

                            

#%% Import Player and Team possession data from previous 2 years
df_import = pd.ExcelFile(r'C:\Users\daviesb\Desktop\NBA\2019-2020\Data for Projections.xlsx')
df_player_2018 = pd.read_excel(df_import, '2018 Player Poss').rename(columns={'FPPP':'FPPP_2018'})
df_player_2019 = pd.read_excel(df_import, '2019 Player Poss').rename(columns={'FPPP':'FPPP_2019'})
df_team_2018 = pd.read_excel(df_import, '2018 Team Poss').rename(columns={'Pace':'Pace_2018'})
df_team_2019 = pd.read_excel(df_import, '2019 Team Poss').rename(columns={'Pace':'Pace_2019'})
df_SD_2018 = pd.read_excel(df_import, '2018 SD').rename(columns={'SD':'SD_2018'})
df_SD_2019 = pd.read_excel(df_import, '2019 SD').rename(columns={'SD':'SD_2019'})

### merge player per 100 poss data
df_player_combined = pd.merge(df_player_2018, df_player_2019, on='Name', how='outer').merge(df_player_poss[['Name', 'FPPP_2020']], on='Name', how='outer')

### ok this one is tricky...if there is no 2019 FPPP, fill it with 2018. if there is no 2020 FPPP, fill it with 2019...etc
df_player_combined['FPPP_2019'].fillna(df_player_combined['FPPP_2018'], inplace=True)
df_player_combined['FPPP_2020'].fillna(df_player_combined['FPPP_2019'], inplace=True)
df_player_combined['FPPP_2018'].fillna(df_player_combined['FPPP_2019'], inplace=True)
df_player_combined['FPPP_2019'].fillna(df_player_combined['FPPP_2020'], inplace=True)
df_player_combined['FPPP_2018'].fillna(df_player_combined['FPPP_2019'], inplace=True)

### calc weighted average of FPPP
df_player_combined['FPPP_WtdAvg'] = np.nansum(df_player_combined[['FPPP_2018', 'FPPP_2019', 'FPPP_2020']] * FPPP_weights, axis=1)
df_player_combined['FPPP_WtdAvg'] = np.where( (np.isnan(df_player_combined['FPPP_2018']) &
                                              np.isnan(df_player_combined['FPPP_2019']) &
                                              np.isnan(df_player_combined['FPPP_2020'])), None, df_player_combined['FPPP_WtdAvg']).astype(float)

### merge pace stats and calc weighted avg
df_team_combined = pd.merge(df_team_2018, df_team_2019[['Team', 'Pace_2019']], on='Team', how='outer').merge(df_team_2020[['Team', 'Pace_2020']], on='Team', how='outer')
df_team_combined['Pace_WtdAvg'] = np.nansum(df_team_combined[['Pace_2018', 'Pace_2019', 'Pace_2020']] * Pace_weights, axis=1)
df_team_combined['Pace_diff'] = df_team_combined['Pace_WtdAvg'] - df_team_combined['Pace_WtdAvg'][30]
### append team pace data to matchup df
df_matchups = pd.merge(df_matchups, df_team_combined[['Abbr', 'Pace_diff']], on='Abbr', how='left')
df_matchups = pd.merge(df_matchups, df_team_combined[['Abbr', 'Pace_diff']], left_on='Opp', right_on='Abbr', how='left').rename(columns={'Abbr_x':'Abbr'})
df_matchups['Pace_diff_total'] = df_matchups['Pace_diff_x'] + df_matchups['Pace_diff_y']

### merge SD stats and calc weighted avg
df_SD_combined = pd.merge(df_SD_2018, df_SD_2019, on='Name', how='outer').merge(df_SD_2020, on='Name', how='outer')
### ok this one is tricky...if there is no 2019 SD, fill it with 2018. if there is no 2020 SD, fill it with 2019...etc
df_SD_combined['SD_2019'].fillna(df_SD_combined['SD_2018'], inplace=True)
df_SD_combined['SD_2020'].fillna(df_SD_combined['SD_2019'], inplace=True)
df_SD_combined['SD_2018'].fillna(df_SD_combined['SD_2019'], inplace=True)
df_SD_combined['SD_2019'].fillna(df_SD_combined['SD_2020'], inplace=True)
df_SD_combined['SD_2018'].fillna(df_SD_combined['SD_2019'], inplace=True)

df_SD_combined['SD_WtdAvg'] = np.nansum(df_SD_combined[['SD_2018', 'SD_2019', 'SD_2020']] * SD_weights, axis=1)


#%% Scrape mins from 538
team_list = ['76ers','bucks','bulls','cavaliers','celtics','clippers','grizzlies','hawks','heat','hornets','jazz','kings','knicks','lakers',
             'magic','mavericks','nets','nuggets','pacers','pelicans','pistons','raptors','rockets','spurs','suns','thunder','timberwolves',
             'trail-blazers','warriors','wizards']

df_538 = pd.DataFrame(columns = ['Name','PG','SG','SF','PF','C','Mins 538','vs Full Strength','off rat','def rat'])

for team in team_list:

    url = str('https://projects.fivethirtyeight.com/2020-nba-predictions/' + team)
    response = requests.get(url)
    
    soup = bs(response.text, 'html.parser')
    table = soup.find_all('div', id='current')
    
    df = pd.read_html(str(table))[0]
    
    df.drop(df.tail(3).index, inplace=True)
    df.drop(df.columns[1], axis=1, inplace=True)
    df.drop(df.columns[8:11], axis=1, inplace=True)
    df.drop(df.columns[10:14], axis=1, inplace=True)
    
    df.columns = ['Name',
                  'PG',
                  'SG',
                  'SF',
                  'PF',
                  'C',
                  'Mins 538',
                  'vs Full Strength',
                  'off rat',
                  'def rat']

    df_538 = df_538.append(df, ignore_index=True)
    
df_538 = df_538[df_538['Name'] != 'Rotation ratings']
df_538 = df_538[df_538['Name'] != 'Adj. rotation ratings']

    
cols = [1, 2, 3, 4, 5, 6]
df_538.iloc[:, cols] = df_538.iloc[:, cols].apply(pd.to_numeric)
df_538_mins = df_538[['Name', 'Mins 538']]
df_538_mins['Name'] = df_538_mins['Name'].map(lambda x: x.rstrip('*'))
df_538_mins.Name.replace({'Tim Hardaway Jr.':'Tim Hardaway',
                          'Jaren Jackson Jr.':'Jaren Jackson',
                          'PJ Tucker':'P.J. Tucker',
                          'Danuel House Jr.':'Danuel House',
                          'Kevin Porter Jr.':'Kevin Porter',
                          'Larry Nance Jr.':'Larry Nance',
                          'Glenn Robinson III':'Glenn Robinson',
                          'Otto Porter Jr.':'Otto Porter',
                          'Robert Williams III':'Robert Williams',
                          'Troy Brown Jr.':'Troy Brown',
                          'Harry Giles III':'Harry Giles',
                          'James Ennis III':'James Ennis',
                          'TJ Leaf':'T.J. Leaf',
                          'Wendell Carter Jr.':'Wendell Carter',
                          'PJ Washington':'P.J. Washington',
                          'Kelly Oubre Jr.':'Kelly Oubre',
                          'CJ Miles':'C.J. Miles',
                          'Michael Porter Jr.':'Michael Porter',
                          'Ty Wallace':'Tyrone Wallace',
                          'Derrick Jones Jr.':'Derrick Jones',
                          'Marvin Bagley III':'Marvin Bagley',
                          'Lonnie Walker IV':'Lonnie Walker',
                          'Gary Trent Jr.':'Gary Trent',
                          'Derrick Walton Jr.':'Derrick Walton'}, inplace=True)


#%% Import DvP data for projection modification

df_DvP = pd.read_excel(df_import, 'DvP')
df_DvP[['PG', 'SG', 'SF', 'PF', 'C']] = df_DvP[['PG', 'SG', 'SF', 'PF', 'C']] * DvP_Regress_weight + 1


#%% Create BD Projections and combine all data

### merge 538 mins to agg sheet
df_combined = pd.merge(df_agg, df_538_mins, on='Name', how='left')
df_combined = pd.merge(df_combined, df_DFN[['Name', 'DFN Min']], on='Name', how='left')
df_combined['Avg Min'] = np.nansum(df_combined[['BBM Mins', 'Mins 538', 'DFN Min']] * Minute_weights, axis=1).astype(float)
df_combined['Mins Diff'] = (df_combined['BBM Mins'] - df_combined['DFN Min']).astype(float)

### join with team data
df_combined = pd.merge(df_combined, df_matchups[['Abbr', 'Pace_diff_total']], on='Abbr', how='left')
df_combined['Pace_adjusted'] = df_team_combined['Pace_WtdAvg'][30] + df_combined['Pace_diff_total']
df_combined['Poss'] = df_combined['Avg Min'] / 48 * df_combined['Pace_adjusted']

### join with FPPP data
df_combined = pd.merge(df_combined, df_player_combined[['Name', 'FPPP_WtdAvg']], on='Name', how='left')
df_combined = pd.merge(df_combined, df_DFN[['Name', 'DFN Proj']], on='Name', how='left')
df_combined['Opp'] = df_combined['Opp'].map(lambda x: x.lstrip('@ '))
df_combined = pd.merge(df_combined, df_DvP, on='Opp', how='left')
df_combined.loc[df_combined['Pos'] == 'PG', 'DvP'] = df_combined['PG']
df_combined.loc[df_combined['Pos'] == 'SG', 'DvP'] = df_combined['SG']
df_combined.loc[df_combined['Pos'] == 'SF', 'DvP'] = df_combined['SF']
df_combined.loc[df_combined['Pos'] == 'PF', 'DvP'] = df_combined['PF']
df_combined.loc[df_combined['Pos'] == 'C', 'DvP'] = df_combined['C']
df_combined.drop(['PG', 'SG', 'SF', 'PF', 'C'], axis=1, inplace=True)
df_combined['BD Proj'] = (df_combined['Poss'] * df_combined['FPPP_WtdAvg'] / 100) * df_combined['DvP'] + df_combined['Home']
df_combined['Proj Diff'] = df_combined['BBM Proj'] - df_combined['BD Proj']
df_combined['BD Proj'].fillna(df_combined['BBM Proj'], inplace=True)
df_combined['Proj Avg'] = np.nansum(df_combined[['BBM Proj', 'BD Proj', 'DFN Proj']] * Proj_weights, axis=1).astype(float)

### join with SD data
df_combined = pd.merge(df_combined, df_SD_combined, on='Name', how='left')
df_combined['SD Proj'] = df_combined['SD_WtdAvg'] * df_combined['Avg Min'].astype(float)
df_combined['SD Regress'] = np.log(df_combined['Proj Avg']) * 4.5711 - 7
df_combined['SD Regress'] = np.where(df_combined['SD Regress'] < 0, 0, df_combined['SD Regress'])
df_combined['SD Proj'] = np.where(df_combined['SD Proj'] == 0, df_combined['SD Regress'], df_combined['SD Proj'])
df_combined['SD Proj'].fillna(df_combined['SD Regress'], inplace=True)
df_combined['SD Final'] = np.nansum(df_combined[['SD Proj', 'SD Regress']] * SD_Regress_weights, axis=1).astype(float)

df_final = df_combined[['Name', 'Pos', 'Price', 'Proj Avg', 'SD Final']].rename(columns={'Price':'Salary',
                                                                                         'Proj Avg':'Proj',
                                                                                         'SD Final':'SD'})

df_final.Name.replace({'Cam Reddish':'Cameron Reddish'}, inplace=True)


#%% write to uploadR file to be used in sim/optimization

outputFilename = r'C:\Users\daviesb\Desktop\NBA\2019-2020\Agg Sheets\NBA Aggregate ' + date.today().strftime('%m.%d.%Y') + '.xlsx'
df_final.to_excel(r'C:\Users\daviesb\Desktop\NBA\2019-2020\uploadR.xlsx', index=False)
df_combined.to_excel(outputFilename, index=False)

