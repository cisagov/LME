# Folder for all the dashboards

## Wazuh Dashboards: 
For more info on these dashboards see wazuh's documentation: [LINK](https://documentation.wazuh.com/current/integrations-guide/elastic-stack/index.html)
This is the dashboard URL that inspired the current Wazuh dashboards: 
```bash
https://packages.wazuh.com/integrations/elastic/4.x-8.x/dashboards/wz-es-4.x-8.x-dashboards.ndjson
```

## How to update dashboards 
Currently you need to run `ansible-playbook post_install_local.yml` to upload the current LME dashboards.

If you need to reupload them, you can delete the `INSTALLED` file in the appropriate `/opt/lme/dashboards` directory and re-run the `post install` script. 

## Updating to new dashboards and removing old ones (Starting with 1.1.0)
Browse to `Kibana->Stack Management` then select `Saved Objects`.
On the Saved Objects page, you can filter by dashboards.

Select the filter `Type` and select `dashboard`. 

* It is suggested that you export the dashboards first (readme below) so you have a backup. 
You can delete all of the dashboards before importing the new ones. 


### Exporting dashboards: 
It is recommended that you export your dashboards before updating them, especially if you have customized them or created new ones. 
To export the dashboards use the `export_dashboards.py`.
It is easiest to export them from the ubuntu machine where you have installed the ELK stack because the 
default port and hostname are in the script. You will need the user and password for elastic that were printed
on your initial install. 

##### The files will be exported to `./exported`

#### Running on Ubuntu
To get your password you can run: 
```bash
cd ~/LME #OR YOUR CLONE DIRECTORY
source ./scripts/extract_secrets
```

Then you can use the following command to export dashboards:
```bash
./export_dashboards.py -u elastic -p "$elastic"
```

The modules should already be installed on Ubuntu, but If the script complains about missing modules:
```bash
pip install -r requirements.txt 
```

The dashboards will be exported to: `~/LME/dashboards/exported`

#### Running on Windows
You must have python and the modules installed. (You can install python 3 from the Microsoft Store). Then install the requirements: 
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


