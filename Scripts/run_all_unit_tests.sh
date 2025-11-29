#!/usr/bin/env bash
# Usage: ./run_all_unit_tests.sh [Debug|Release|ASAN|UBSAN]

set -e
set -o pipefail

if ! [ -x "$(command -v xcpretty)" ] ; then
    echo 'xcpretty is not found, aborting. (https://github.com/xcpretty/xcpretty)'
    exit -1
fi

# https://github.com/xcpretty/xcpretty/issues/48
export LC_CTYPE=en_US.UTF-8

# https://github.com/google/sanitizers/wiki/AddressSanitizerContainerOverflow#false-positives
export ASAN_OPTIONS=detect_container_overflow=0

# Determine the host architecture
HOST_ARCH=$(uname -m)

# Get current directory
SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Allocate a directory for the build artifacts
BUILD_DIR="${SCRIPTS_DIR}/run_all_unit_tests.tmp"
mkdir "${BUILD_DIR}"

ROOT_DIR=$(cd "$SCRIPTS_DIR/.." && pwd)

XCODEPROJ="../Source/NimbleCommander/NimbleCommander.xcodeproj"

LOG_FILE=${BUILD_DIR}/xcodebuild.log

# Configuration to build the unit tests with
if [ -n "$1" ]; then
    CONFIGURATION="$1"
else
    CONFIGURATION="Debug"
fi

# The target is an umbrella that depends on all unit tests
TARGET="UnitTests"

echo Now building ${TARGET} - ${CONFIGURATION} - ${HOST_ARCH}

# Conditionally inject ASAN flag
asan_flags=""
if [ "$CONFIGURATION" == "ASAN" ]; then
    CONFIGURATION="Release"
    asan_flags="-enableAddressSanitizer YES"
fi

# Conditionally inject UBSAN flag
ubsan_flags=""
if [ "$CONFIGURATION" == "UBSAN" ]; then
    CONFIGURATION="Release"
    ubsan_flags="-enableUndefinedBehaviorSanitizer YES"
fi

# Build the xcodebuild execution command
XC="xcodebuild \
    -project ${XCODEPROJ} \
    -scheme ${TARGET} \
    -configuration ${CONFIGURATION} \
    -destination "platform=macOS,arch=${HOST_ARCH}" \
    SYMROOT=${BUILD_DIR} \
    OBJROOT=${BUILD_DIR} \
    -parallelizeTargets \
    ${asan_flags} \
    ${ubsan_flags}"

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

# Now actually build the unit tests
${XC} build | tee -a ${LOG_FILE} | xcpretty

# Run the produced binaries
for path in "${binary_paths[@]}"; do
    echo Now Running ${path}
    ${path}
done

# Cleanup
rm -rf ${BUILD_DIR}
