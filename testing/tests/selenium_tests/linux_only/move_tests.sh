#!/bin/bash

# Check if the Python file is provided as an argument
if [ $# -eq 0 ]; then
    echo "Please provide the path to the Python file as an argument."
    exit 1
fi

# Get the Python file path from the argument
python_file=$1

# Check if the Python file exists
if [ ! -f "$python_file" ]; then
    echo "The specified Python file does not exist."
    exit 1
fi

# Find all the class definitions in the Python file
class_names=$(grep -oP '(?<=class )\w+' "$python_file")

# Iterate over each class name
for class_name in $class_names; do
    # Convert the class name to snake case
    snake_case_name=$(echo "$class_name" | sed 's/\([A-Z]\)/_\L\1/g;s/^_//')

    # Create a new file with the snake case class name
    new_file="${snake_case_name}.py"

    # Add the import statements to the new file
    echo "import pytest" > "$new_file"
    echo "import os" >> "$new_file"
    echo "from selenium.webdriver.support.ui import WebDriverWait" >> "$new_file"
    echo "from selenium.webdriver.support import expected_conditions as EC" >> "$new_file"
    echo "from selenium.webdriver.common.by import By" >> "$new_file"
    echo "from selenium.common.exceptions import NoSuchElementException" >> "$new_file"
    echo "" >> "$new_file"  # Add an empty line for separation

    # Extract the class and its contents from the original file and append to the new file
    sed -n "/class $class_name/,/class\s\+\w\+\s*:/p" "$python_file" | sed '$d' >> "$new_file"

    # Check if the new file is empty
    if [ ! -s "$new_file" ]; then
        echo "Class '$class_name' not found or empty. Skipping."
        rm "$new_file"
    else
        echo "Extracted class '$class_name' to '$new_file'"
    fi
done