extract_credentials() {
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
