# Folder for all the dashboards


## How to update dashboards
```
./dashboard_update.sh
```

## Customizing dashboards:
When customizing dashboards keep in mind to be sure the name of the file does not conflict with one on git. In future iterations of LME, updates will overwrite any dashboard file that you have customized or named the same as an original file that appears in this directory. 

In addition, any other dashboards you want to save in git and track in this repository can maintained safely (assuming the new files do not overlap in name with any original file in LME) by doing the following:
  1. Creating your own local branch in this LME repo
  2. Commiting any changes
  3. pulling in changes from `main` to your local repo
