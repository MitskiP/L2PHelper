# L2PHelper 

## Description

This script downloads missing homeworks or learning materials from the RWTH-L2P automatically.
The parameter -f forces the script to download all the files from the server again.
While this script is running the owncloud client is paused (if it was running).

L2PHelper depends heavily on wget. Mac OS users do not have wget initially.

## Usage
Call the script in an empty directory. This will create a config file in the same directory which has to be fed with your user name and password for L2P.
Call the script again. Now it will download L2P contents.

## Configuration
The L2PHelper.cfg has to set an array parse[] and the variables user and pw. parse[i] shall look like this:
```
parse[i]='<Module name>//<Menu entry in ENGLISH>[/Path to track]/*'
```
E.g.
```
parse[0]='Formale Systeme, Automaten, Prozesse//Learning Materials/*'
parse[1]='Einführung in die angewandte Stochastik//Learning Materials/*'
parse[2]='Betriebssysteme und Systemsoftware//Learning Materials/*'
parse[3]='Betriebssysteme und Systemsoftware//Shared Documents/Aufgaben für die Übungsgruppen/*'
parse[4]='Betriebssysteme und Systemsoftware//Assignments/*'
user=ab123456
pw=password
```
