#!/bin/bash

# Convert Sigma Rules to Kibana - Standalone Script
# This script downloads the latest Sigma rules, converts them to Kibana-compatible NDJSON format,
# and optionally uploads them to a running Kibana instance
# If ran again will only upload NEW rules.

set -e

echo "Starting Sigma to Kibana conversion..."

if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not installed."
    exit 1
fi

if ! command -v pip &> /dev/null && ! command -v pip3 &> /dev/null; then
    echo "Error: pip is required but not installed."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Error: curl is required but not installed."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq for JSON parsing."
    exit 1
fi

PIP_CMD="pip3"
if ! command -v pip3 &> /dev/null; then
    PIP_CMD="pip"
fi

get_latest_sigma_release() {
    echo "Fetching latest Sigma release information..."

    LATEST_RELEASE=$(curl -s "https://api.github.com/repos/SigmaHQ/sigma/releases/latest")

    TAG_NAME=$(echo "$LATEST_RELEASE" | jq -r '.tag_name')
    DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | jq -r '.assets[] | select(.name | contains("sigma_all_rules.zip")) | .browser_download_url')

    if [ "$TAG_NAME" = "null" ] || [ "$DOWNLOAD_URL" = "null" ]; then
        echo "Error: Could not fetch latest release information from GitHub API"
        echo "Falling back to manual URL construction..."

        TAG_NAME=$(curl -s "https://api.github.com/repos/SigmaHQ/sigma/releases" | jq -r '.[0].tag_name')

        if [ "$TAG_NAME" = "null" ]; then
            echo "Error: Could not determine latest release tag"
            exit 1
        fi

        DOWNLOAD_URL="https://github.com/SigmaHQ/sigma/releases/download/${TAG_NAME}/sigma_all_rules.zip"
    fi

    echo "Latest Sigma release: $TAG_NAME"
    echo "Download URL: $DOWNLOAD_URL"
}

download_sigma_rules() {
    local download_url="$1"
    local tag_name="$2"

    TEMP_DIR=$(mktemp -d)
    ZIP_FILE="$TEMP_DIR/sigma_all_rules.zip"

    echo "Downloading Sigma rules archive..."
    if curl -L -o "$ZIP_FILE" "$download_url"; then
        echo "Download successful!"
    else
        echo "Error: Failed to download Sigma rules from $download_url"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    if [ -d "sigma" ]; then
        echo "Removing existing sigma directory..."
        rm -rf sigma
    fi

    echo "Extracting Sigma rules..."
    if command -v unzip &> /dev/null; then
        unzip -o -q "$ZIP_FILE" -d .
    else
        echo "Error: unzip command not found. Please install unzip."
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "*sigma*" | head -n 1)

    if [ -z "$EXTRACTED_DIR" ]; then
        if [ -d "rules" ]; then
            echo "Found rules directory, creating sigma structure..."
            mkdir -p sigma
            mv rules sigma/
        else
            echo "Error: Could not find expected directory structure after extraction"
            ls -la
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        if [ "$EXTRACTED_DIR" != "./sigma" ]; then
            echo "Renaming extracted directory to 'sigma'..."
            mv "$EXTRACTED_DIR" sigma
        fi
    fi

    rm -rf "$TEMP_DIR"

    echo "Sigma rules extracted successfully!"
    echo "Release version: $tag_name"
}

get_latest_sigma_release

download_sigma_rules "$DOWNLOAD_URL" "$TAG_NAME"

if [ ! -d "sigma/rules" ]; then
    echo "Error: Expected directory structure not found. Looking for rules..."
    find sigma -name "*.yml" -type f | head -5
    if [ ! -d "sigma/rules/windows" ]; then
        echo "Warning: sigma/rules/windows directory not found"
        echo "Available directories in sigma:"
        find sigma -type d | head -10
    fi
fi

echo "Installing sigma-cli and elasticsearch plugin..."
$PIP_CMD install --upgrade pip
$PIP_CMD install sigma-cli

sigma plugin install elasticsearch

mkdir -p output

echo ""
echo "=========================================="
echo "CONVERTING SIGMA RULES TO KIBANA FORMAT"
echo "=========================================="
echo ""

echo "Converting Sigma Windows rules to Kibana format..."

if [ -d "sigma/rules/windows" ]; then
    find ./sigma/rules/windows -type f -name "*.yml" > windows_rules.txt
elif [ -d "sigma/rules" ]; then
    find ./sigma/rules -type f -name "*.yml" | grep -i windows > windows_rules.txt
else
    echo "Error: Could not find Sigma rules directory"
    exit 1
fi

if [ ! -s windows_rules.txt ]; then
    echo "Error: No Windows rules found"
    echo "Available rule files:"
    find sigma -name "*.yml" -type f | head -10
    exit 1
fi

echo "Found $(wc -l < windows_rules.txt) Windows rules"

echo "Converting Windows rules..."
if sigma convert -t lucene -p ecs_windows -f siem_rule_ndjson --skip-unsupported $(cat windows_rules.txt) > output/sigma_windows_rules.ndjson 2>/dev/null; then
    if [ -f "output/sigma_windows_rules.ndjson" ] && [ -s "output/sigma_windows_rules.ndjson" ]; then
        echo "SUCCESS: $(wc -l < output/sigma_windows_rules.ndjson) Windows rules converted"
    else
        echo "ERROR: 0 Windows rules converted"
        rm -f output/sigma_windows_rules.ndjson
    fi
else
    echo "ERROR: Windows conversion failed"
fi

echo ""
echo "=========================================="
echo ""

echo "Converting Sigma macOS rules to Kibana format..."

find ./sigma/rules/macos -type f -name "*.yml" > macos_rules.txt

if [ -s macos_rules.txt ]; then
    echo "Found $(wc -l < macos_rules.txt) macOS rules"
    echo "Converting macOS rules..."
    if sigma convert -t lucene -f siem_rule_ndjson --without-pipeline --skip-unsupported $(cat macos_rules.txt) > output/sigma_macos_rules.ndjson 2>/dev/null; then
        if [ -f "output/sigma_macos_rules.ndjson" ] && [ -s "output/sigma_macos_rules.ndjson" ]; then
            echo "SUCCESS: $(wc -l < output/sigma_macos_rules.ndjson) macOS rules converted"
        else
            echo "ERROR: 0 macOS rules converted"
            rm -f output/sigma_macos_rules.ndjson
        fi
    else
        echo "ERROR: macOS conversion failed"
    fi
else
    echo "No macOS rules found"
fi

echo ""
echo "=========================================="
echo ""

echo "Converting Sigma Linux rules to Kibana format..."

find ./sigma/rules/linux -type f -name "*.yml" > linux_rules.txt

if [ -s linux_rules.txt ]; then
    echo "Found $(wc -l < linux_rules.txt) Linux rules"
    echo "Converting Linux rules..."
    if sigma convert -t lucene -f siem_rule_ndjson --without-pipeline --skip-unsupported $(cat linux_rules.txt) > output/sigma_linux_rules.ndjson 2>/dev/null; then
        if [ -f "output/sigma_linux_rules.ndjson" ] && [ -s "output/sigma_linux_rules.ndjson" ]; then
            echo "SUCCESS: $(wc -l < output/sigma_linux_rules.ndjson) Linux rules converted"
        else
            echo "ERROR: 0 Linux rules converted"
            rm -f output/sigma_linux_rules.ndjson
        fi
    else
        echo "ERROR: Linux conversion failed"
    fi
else
    echo "No Linux rules found"
fi

echo "Modifying rules for Kibana compatibility..."

if [ -f "output/sigma_windows_rules.ndjson" ]; then
    sed -i 's/"tags": \[[^]]*\]/"tags": ["Sigma Windows"]/g; s/"severity": "informational"/"severity": "low"/g; s/"enabled": true/"enabled": false/g' output/sigma_windows_rules.ndjson
fi

if [ -f "output/sigma_macos_rules.ndjson" ]; then
    sed -i 's/"tags": \[[^]]*\]/"tags": ["Sigma macOS"]/g; s/"severity": "informational"/"severity": "low"/g; s/"enabled": true/"enabled": false/g' output/sigma_macos_rules.ndjson
fi

if [ -f "output/sigma_linux_rules.ndjson" ]; then
    sed -i 's/"tags": \[[^]]*\]/"tags": ["Sigma Linux"]/g; s/"severity": "informational"/"severity": "low"/g; s/"enabled": true/"enabled": false/g' output/sigma_linux_rules.ndjson
fi

rm -f windows_rules.txt macos_rules.txt linux_rules.txt

echo ""
echo "=========================================="
echo "CONVERSION COMPLETE"
echo "=========================================="
echo "Sigma Release: $TAG_NAME"
echo ""

echo "CONVERSION RESULTS:"
echo "----------------------------------------"
total_converted=0
for file in output/sigma_*_rules.ndjson; do
    if [ -f "$file" ]; then
        rule_count=$(wc -l < "$file")
        os_type=$(basename "$file" | sed 's/sigma_\(.*\)_rules\.ndjson/\1/')
        echo "$os_type: $rule_count rules converted"
        total_converted=$((total_converted + rule_count))
    fi
done
echo "----------------------------------------"
echo "Total: $total_converted rules ready for Kibana"

echo ""
echo "UPLOAD TO KIBANA"
echo "----------------------------------------"

read -p "Upload rules to Kibana now? (y/N): " upload_choice

if [[ $upload_choice =~ ^[Yy]$ ]]; then
    echo ""
    echo "Checking Kibana connection..."

    if ELASTIC_USERNAME=$(sudo -i podman exec lme-elasticsearch printenv ELASTIC_USERNAME 2>/dev/null) && \
       ELASTIC_PASSWORD=$(sudo -i podman exec lme-elasticsearch printenv ELASTIC_PASSWORD 2>/dev/null); then

        echo "Found Elasticsearch credentials"
        echo ""

        for rule_file in output/sigma_*_rules.ndjson; do
            if [ -f "$rule_file" ]; then
                os_type=$(basename "$rule_file" | sed 's/sigma_\(.*\)_rules\.ndjson/\1/')

                echo "Uploading $os_type rules..."

                UPLOAD_RESULT=$(curl -s -k -X POST \
                    -u "${ELASTIC_USERNAME}:${ELASTIC_PASSWORD}" \
                    "https://localhost:5601/api/detection_engine/rules/_import" \
                    -H "kbn-xsrf: true" \
                    -H "Content-Type: multipart/form-data" \
                    --form file=@"$rule_file")

                if echo "$UPLOAD_RESULT" | grep -q "rules_count\|success_count\|created_count\|updated_count\|rules_installed"; then
                    echo "SUCCESS: $os_type rules uploaded"
                else
                    echo "WARNING: Upload may have failed, trying alternative method..."

                    UPLOAD_RESULT2=$(sudo -i podman exec lme-elasticsearch bash -c "
                        curl -s -X POST 'kibana:5601/api/detection_engine/rules/_import' \
                        -H 'kbn-xsrf: true' \
                        -H 'Content-Type: multipart/form-data' \
                        -u \"\${ELASTIC_USERNAME}:\${ELASTIC_PASSWORD}\" \
                        --form file=@<(cat > /tmp/upload.ndjson <<'EOF'
$(cat "$rule_file")
EOF
cat /tmp/upload.ndjson && rm -f /tmp/upload.ndjson)
                    ")

                    if echo "$UPLOAD_RESULT2" | grep -q "rules_count\|success_count\|created_count\|updated_count\|rules_installed"; then
                        echo "SUCCESS: $os_type rules uploaded via container network"
                    else
                        echo "ERROR: Both upload methods failed for $os_type"
                    fi
                fi
            fi
        done

    else
        echo "ERROR: Could not get Elasticsearch credentials"
        echo "Please ensure the lme-elasticsearch container is running"
    fi
else
    echo ""
    echo "MANUAL UPLOAD INSTRUCTIONS:"
    echo "----------------------------------------"
    echo "1. Open Kibana: https://localhost:5601"
    echo "2. Navigate to: Security -> Rules"
    echo "3. Click: Import Rules"
    echo "4. Upload files from: ./output/ directory"
    echo ""
    echo "Files to upload:"
    for rule_file in output/sigma_*_rules.ndjson; do
        if [ -f "$rule_file" ]; then
            echo "   $(basename "$rule_file")"
        fi
    done
fi

echo ""
echo "IMPORTANT: All rules are disabled by default for security"
echo "Review and enable rules individually in Kibana"
echo ""
echo "Script completed successfully!"