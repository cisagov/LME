extract_credentials() {
    local file_path=${1:-'/opt/lme/Chapter 3 Files/output.log'}
    if [ ! -f "$file_path" ]; then
        echo "File not found: $file_path"
        return 1
    fi

    # Use a while loop directly reading from a process substitution
    while IFS=: read -r line rest; do
        line=$(echo "$line" | sed 's/^## //g' | xargs)
        rest=$(echo "$rest" | xargs)

        key=$(echo "$line" | awk '{print $1}')
        value=$rest

        case $key in
            "elastic" | "kibana" | "logstash_system" | "logstash_writer" | "dashboard_update")
                export "$key"="$value"
                ;;
        esac
    done < <(awk '/^## \w+:/{print $0}' "$file_path")

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