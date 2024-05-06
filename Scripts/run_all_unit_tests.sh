#!/bin/sh
# Usage: ./run_all_unit_tests.sh [Debug|Release|ASAN|UBSAN]

set -e
set -o pipefail

if ! [ -x "$(command -v xcpretty)" ] ; then
    echo 'xcpretty is not found, aborting. (https://github.com/xcpretty/xcpretty)'
    exit -1
fi

# https://github.com/xcpretty/xcpretty/issues/48
export LC_CTYPE=en_US.UTF-8

# get current directory
SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# allocate a dir for build artifacts
BUILD_DIR="${SCRIPTS_DIR}/run_all_unit_tests.tmp"
mkdir "${BUILD_DIR}"

ROOT_DIR=$(cd "$SCRIPTS_DIR/.." && pwd)

XCODEPROJ="../Source/NimbleCommander/NimbleCommander.xcodeproj"

LOG_FILE=${BUILD_DIR}/xcodebuild.log

build_target()
{
    TARGET=$1
    CONFIGURATION=$2
    echo building ${TARGET} - ${CONFIGURATION}
    
    asan_flags=""
    if [ "$CONFIGURATION" == "ASAN" ]; then
        CONFIGURATION="Release"
        asan_flags="-enableAddressSanitizer YES"
    fi

    ubsan_flags=""
    if [ "$CONFIGURATION" == "UBSAN" ]; then
        CONFIGURATION="Release"
        ubsan_flags="-enableUndefinedBehaviorSanitizer YES"
    fi

    XC="xcodebuild \
        -project ${XCODEPROJ} \
        -scheme ${TARGET} \
        -configuration ${CONFIGURATION} \
        SYMROOT=${BUILD_DIR} \
        OBJROOT=${BUILD_DIR} \
        -parallelizeTargets \
        ${asan_flags} \
        ${ubsan_flags} \
        OTHER_CFLAGS=\"-fdebug-prefix-map=${ROOT_DIR}=.\""
    BINARY_DIR=$($XC -showBuildSettings | grep " BUILT_PRODUCTS_DIR =" | sed -e 's/.*= *//')
    BINARY_NAME=$($XC -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//')
    BINARY_PATH=$BINARY_DIR/$BINARY_NAME
    $XC build | tee -a ${LOG_FILE} | xcpretty
}

# list of targets to build
tests=$(xcodebuild -project ${XCODEPROJ} -list | awk -v word="Schemes:" 'BEGIN {found=0} found {if ($0 ~ /UT$/) print} $0 ~ word {found=1}' | sed 's/^[[:space:]]*//')
echo Building these unit tests: ${tests}

# list of configurations to build the targets with
if [ -n "$1" ]; then
    configurations="$1"
else
    configurations="Debug Release"
fi
echo Building these configurations: ${configurations}

# a list of binaries of UTs to execute
binary_paths=()

# build N * M binaries
for configuration in ${configurations}; do
  for test in ${tests}; do
    # build the binary
    build_target ${test} ${configuration}
    
    # store the path to execute later
    binary_paths+=("$BINARY_PATH")
  done
done

# run the binaries
for path in "${binary_paths[@]}"; do
    echo "$path"
    $path
done

# cleanup
rm -rf ${BUILD_DIR}
