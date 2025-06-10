#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# change as needed
LME_BASE_PATH="${SCRIPT_DIR}/../../"
SBOM_OUTPUT_DIR="${SCRIPT_DIR}/output"

OUTPUT_FORMAT="spdx-json" #can change to spdx
OUTPUT_FILETYPE="json"

mkdir -p "$SBOM_OUTPUT_DIR"

echo "Starting the SBOM generation..."

if [ "$EUID" -ne 0 ]; then
    echo "please run as root, and use the -i flag"
    exit
fi

echo "Checking if syft exists as an executable"
if ! command -v syft 2>&1 > /dev/null; then
    echo "Syft does not exist, downloading..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
fi


echo "Starting podman socket for syft container analysis"
# By default podman is not running its socket. Need to turn
# it on so syft can access the images.
podman system service --time=0 tcp://localhost:9394 &
export DOCKER_HOST=tcp://localhost:9394

images=$(podman images | grep localhost | awk {'print $1'})

for img in $images; do
    echo "Analyzing image $img:LME_LATEST"
    # the {img//\//-} replaces / with -, so localhost-kibana instead of slash
    output_path="${SBOM_OUTPUT_DIR}/${img//\//-}.${OUTPUT_FILETYPE}"
    output_table="${SBOM_OUTPUT_DIR}/${img//\//-}-table.txt"
    syft "$img:LME_LATEST" -o spdx-json="$output_path" -o syft-table="${output_table}" 2>/dev/null
done

syft dir:${LME_BASE_PATH} -o spdx-json="${SBOM_OUTPUT_DIR}/directory.${OUTPUT_FILETYPE}" -o syft-table="${SBOM_OUTPUT_DIR}/directory-table.txt"

echo "Stopping podman socket"
pkill -f "podman system service"

echo "SBOM generation completed. View generated SBOMs in ${SBOM_OUTPUT_DIR}."
