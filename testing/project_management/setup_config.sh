#!/usr/bin/env bash

# Parse named arguments
while getopts ":s:e:f:" opt; do
  case $opt in
    s) start_date="$OPTARG";;
    e) end_date="$OPTARG";;
    f) file_path="$OPTARG";;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1;;
  esac
done

# Validate start_date and end_date
if [ -z "$start_date" ]; then
  echo "Start date is required. Use -s option to specify the start date."
  exit 1
fi

if [ -z "$end_date" ]; then
  echo "End date is required. Use -e option to specify the end date."
  exit 1
fi

# Validate date format
date_regex="^[0-9]{4}-[0-9]{2}-[0-9]{2}$"

if ! [[ $start_date =~ $date_regex ]]; then
  echo "Invalid start date format. Please use the format YYYY-mm-dd."
  exit 1
fi

if ! [[ $end_date =~ $date_regex ]]; then
  echo "Invalid end date format. Please use the format YYYY-mm-dd."
  exit 1
fi

# Set default file path if not provided
if [ -z "$file_path" ]; then
  file_path="/github-projects-burndown-chart/src/github_projects_burndown_chart/config/config.json"
fi

# Create the directory if it doesn't exist
mkdir -p "$(dirname "$file_path")"

# Generate the JSON content with the provided start_date and end_date
echo '{
  "cisagov": {
    "LME": {
      "query_variables": {
        "organization_name": "cisagov",
        "project_number": 68,
        "column_count": 5,
        "max_cards_per_column_count": 50,
        "labels_per_issue_count": 5
      },
      "settings": {
        "sprint_start_date": "'"$start_date"'",
        "sprint_end_date": "'"$end_date"'",
        "points_label": "Points: "
      }
    }
  }
}' > "$file_path"