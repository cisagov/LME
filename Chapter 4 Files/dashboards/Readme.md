# Folder for all the dashboards


## How to update dashboards
```
./dashboard_update.sh
```

## Exporting dashboards:
It is recommended that you export your dashboards before updating them, especially if you have customized them or created new ones. 
To export the dashboards use the `export_dashboards.py` file in the Chapter 4 directory. 
It is easiest to export them from the ubuntu machine where you have installed the ELK stack because the 
default port and hostname are in the script. You will need the user and password for elastic that were printed
on your initial install. 

##### The files will be exported to `Chapter 4 Files/exported`

#### Running on Ubuntu
Change to the `Chapter 4 Files` directory and run:
```
./export_dashboards.py -u elastic -p YOURUNIQUEPASS
```
The modules should already be installed on Ubuntu, but If the script complains about missing modules:
```
pip install -r requirements.txt 
```

#### Running on Windows
You must have python and the modules installed. (You can install python 3 from the Microsoft Store) Then make 
sure you are in the `Chapter 4 Files` directory and install the requirements.
```
pip install -r requirements.txt
``` 

You will probably have to pass the host that you connect to for kibana when running on windows.
```
python .\export_dashboards.py -u elastic -p YOURUNIQUEPASS --host x.x.x.x
```

## Customizing dashboards:
When customizing dashboards keep in mind to be sure the name of the file does not conflict with one on git. In future iterations of LME, updates will overwrite any dashboard file that you have customized or named the same as an original file that appears in this directory. 

In addition, any other dashboards you want to save in git and track in this repository can maintained safely (assuming the new files do not overlap in name with any original file in LME) by doing the following:
  1. Creating your own local branch in this LME repo
  2. Commiting any changes
  3. pulling in changes from `main` to your local repo


