#!/bin/bash

# Function to fix dashboard title
fix_dashboard_title() {
    local file="$1"
    local temp_file="${file}.tmp"

    # Process the file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        if echo "$line" | jq -e 'select(.type == "dashboard")' > /dev/null 2>&1; then
            # It's a dashboard object, update the title
            updated_line=$(echo "$line" | jq -c '
                if .attributes.title and (.attributes.title | startswith("1x-") | not) then
                    .attributes.title = "1x-" + .attributes.title
                else
                    .
                end
            ')
            echo "$updated_line" >> "$temp_file"
        else
            # Not a dashboard object, keep the line as is
            echo "$line" >> "$temp_file"
        fi
    done < "$file"

    # Replace the original file with the updated one
    mv "$temp_file" "$file"
    echo "Updated $file"
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install jq to run this script."
    exit 1
fi

# Check if a directory was provided
if [ $# -eq 0 ]; then
    echo "Error: No directory specified"
    echo "Usage: $0 <directory>"
    exit 1
fi

DASHBOARDS_DIR="$1"

# Check if the provided directory exists
if [ ! -d "$DASHBOARDS_DIR" ]; then
    echo "Error: Directory not found: $DASHBOARDS_DIR"
    exit 1
fi

# Process all .ndjson files in the specified directory
echo "Processing .ndjson files in $DASHBOARDS_DIR"
for file in "$DASHBOARDS_DIR"/*.ndjson; do
    if [[ -f "$file" ]]; then
        fix_dashboard_title "$file"
    fi
done

echo "All .ndjson files have been processed."