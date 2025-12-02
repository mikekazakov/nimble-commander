#!/bin/sh

set -e
set -o pipefail

if ! [ -x "$(command -v xcpretty)" ] ; then
    echo 'xcpretty is not found, aborting. (https://github.com/xcpretty/xcpretty)'
    exit -1
fi

if ! [ -x "$(command -v docker)" ] ; then
    echo 'docker is not found, aborting. (https://www.docker.com)'
    exit -1
fi

# https://github.com/xcpretty/xcpretty/issues/48
export LC_CTYPE=en_US.UTF-8

# https://github.com/google/sanitizers/wiki/AddressSanitizerContainerOverflow#false-positives
export ASAN_OPTIONS=detect_container_overflow=0

# Determine the host architecture
HOST_ARCH=$(uname -m)

# get current directory
SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="${SCRIPTS_DIR}/.."

# allocate a temp dir for build artifacts
BUILD_DIR="${SCRIPTS_DIR}/run_all_integration_tests.tmp"
mkdir -p "${BUILD_DIR}"

LOG_FILE=${BUILD_DIR}/xcodebuild.log

# start up the docker stuff
echo "=== Starting docker dependencies ==="
cd ${ROOT_DIR}/Source/VFS/tests/data/docker
./start.sh

# stop the docker stuff in a cleanup function
function cleanup {
  echo "=== Stopping docker dependencies ==="
  ${ROOT_DIR}/Source/VFS/tests/data/docker/stop.sh
}
trap cleanup EXIT

# go to the scripts directory
cd ${SCRIPTS_DIR}

# Build the xcodebuild execution command
XC="xcodebuild \
    -project ../Source/NimbleCommander/NimbleCommander.xcodeproj \
    -scheme IntegrationTests \
    -configuration Debug \
    -destination "platform=macOS,arch=${HOST_ARCH}" \
    SYMROOT=${BUILD_DIR} \
    OBJROOT=${BUILD_DIR} \
    -enableAddressSanitizer YES \
    -parallelizeTargets"

# Extract the directories and the names of the built unit test binaries
DIRS="$($XC -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR =' | sed -e 's/.*= *//')"
NAMES="$($XC -showBuildSettings 2>/dev/null | grep ' FULL_PRODUCT_NAME =' | sed -e 's/.*= *//')"

# Fill dirs[]
dirs=()
while IFS= read -r d; do
    dirs+=("$d")
done <<< "$DIRS"

# Fill names[]
names=()
while IFS= read -r n; do
    names+=("$n")
done <<< "$NAMES"
    
# Sanity check: both arrays must have same length
if [[ ${#dirs[@]} -ne ${#names[@]} ]]; then
    echo "Mismatch: ${#dirs[@]} dirs vs ${#names[@]} names" >&2
    exit 1
fi

# Combine them to build full binary paths
binary_paths=()
for ((i=0; i<${#names[@]}; i++)); do
    binary_paths+=("${dirs[$i]}/${names[$i]}")
done

# Now actually build the integration tests tests
${XC} build | tee -a ${LOG_FILE} | xcpretty

# Run the produced binaries
for path in "${binary_paths[@]}"; do
    echo Now Running ${path}
    ${path}
done

# cleanup
rm -rf ${BUILD_DIR}
