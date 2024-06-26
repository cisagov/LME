extract_credentials() {
<<<<<<< HEAD
  local file_path=${1:-'/opt/lme/Chapter 3 Files/output.log'}

  if [ ! -f "$file_path" ]; then
    echo "File not found: $file_path"
    return 1
  fi

  # Use sed to extract the lines containing the credentials
  credentials=$(sed -n '/^## [a-zA-Z_]*:/p' "$file_path")

  # Loop through the extracted lines and assign the values to variables
  while IFS=: read -r key value; do
    key=$(echo "$key" | sed 's/^## //g' | tr -d '[:space:]')
    value=$(echo "$value" | tr -d '\r\n')
    export "$key"="$value"
  done <<< "$credentials"

  export ELASTIC_PASSWORD=$elastic
}

write_credentials_to_file() {
    local file_path=$1
    # exit if file path is not provided
    if [ -z "$file_path" ]; then
        echo "File path is required"
        return 1
    fi
    # Write credentials to the file
    echo "export elastic=$elastic" > "$file_path"
    echo "export kibana=$kibana" >> "$file_path"
    echo "export logstash_system=$logstash_system" >> "$file_path"
    echo "export logstash_writer=$logstash_writer" >> "$file_path"
    echo "export dashboard_update=$dashboard_update" >> "$file_path"
}


extract_ls1_ip() {
    local file_path=$1
    # exit if file path is not provided
    if [ -z "$file_path" ]; then
        echo "File path is required"
        return 1
    fi
    publicIpAddress=$(sed -n '/Creating LS1.../,/}/p' $file_path | awk -F'"' '/publicIpAddress/{print $4}')
    export LS1_IP=$publicIpAddress
}
=======
    # Set default file path if not provided
    local file_path=${1:-'/opt/lme/Chapter 3 Files/output.log'}

    # Check if the file exists
    if [ ! -f "$file_path" ]; then
        echo "File not found: $file_path"
        return 1
    fi

    # Read and extract credentials from the last 18 lines
    while IFS= read -r line; do
        # Remove leading '## ' and trim whitespaces from the line
        line=$(echo "$line" | sed 's/^## //g' | xargs)

        # Split the line into key and value
        key=$(echo "$line" | awk -F ':' '{print $1}')
        value=$(echo "$line" | awk -F ':' '{print $2}' | xargs)  # xargs to trim whitespaces from value

        # Remove non-word characters (keep only word characters)
        value=$(echo "$value" | sed 's/[^[:alnum:]_]//g')

        case $key in
            "elastic") export elastic=$value ;;
            "kibana") export kibana=$value ;;
            "logstash_system") export logstash_system=$value ;;
            "logstash_writer") export logstash_writer=$value ;;
            "dashboard_update") export dashboard_update=$value ;;
        esac
    done < <(tail -n 18 "$file_path" | grep -E "(elastic|kibana|logstash_system|logstash_writer|dashboard_update):")
}
>>>>>>> origin/release-1.4.0
