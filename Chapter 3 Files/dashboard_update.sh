#!/bin/bash
LME_DIR=/opt/lme/
IFS=$'\n'
Dashboards="$(ls -1 ${LME_DIR}Chapter\ 4\ Files/dashboards/*.ndjson)"
echo $Dashboards


if [ -r /opt/lme/lme.conf ]; then
  #reference this file as a source
  . /opt/lme/lme.conf
  #check if the version number is equal to the one we want
  if [ "$version" == "1.3.0" ] || [ "$FRESH_INSTALL" = "true" ]; then
    echo -e "\e[32m[X]\e[0m Updating from git repo"
    git -C /opt/lme/ pull
    #make sure the hostname variable is present
    #echo -e "\e[32m[X]\e[0m Updating stored dashboard file"
    if [ -n "$hostname" ]; then

      echo -e "\e[32m[X]\e[0m Uploading the new dashboards to Kibana"
      for db in ${Dashboards};
      do
        echo -e "\e[32m[X]\e[0m Uploading ${db%%*.} dashboard\n"
        curl -X POST -k --user dashboard_update:dashboardupdatepassword -H 'kbn-xsrf: true' --form file="@${dashbaord_dir}/${db}" "https://127.0.0.1/api/saved_objects/_import?overwrite=true"
        echo
      done

    fi
  else 
    echo "!!Upgrade to 1.3.0!!"
  fi

fi
