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

build_target()
{
    TARGET=$1
    echo building ${TARGET} - ${CONFIGURATION}
    XC="xcodebuild \
        -project ../Source/NimbleCommander/NimbleCommander.xcodeproj \
        -scheme ${TARGET} \
        -configuration Debug \
        SYMROOT=${BUILD_DIR} \
        OBJROOT=${BUILD_DIR} \
        -enableAddressSanitizer YES \
        -parallelizeTargets"
    BINARY_DIR=$($XC -showBuildSettings | grep " BUILT_PRODUCTS_DIR =" | sed -e 's/.*= *//')
    BINARY_NAME=$($XC -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//')
    BINARY_PATH=$BINARY_DIR/$BINARY_NAME
    $XC build | tee -a ${LOG_FILE} | xcpretty
}

# list of targets to build
tests=(\
VFSIconIT \
VFSIT \
OperationsIT \
TermIT \
)

for test in ${tests[@]}; do
  # build the binary
  build_target $test
    
  # execute the binary
  $BINARY_PATH
done

# cleanup
rm -rf ${BUILD_DIR}
