#!/bin/sh

set -o pipefail

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BUILD_DIR=$(mktemp -d ${SCRIPTS_DIR}/build.XXXXXXXXX)
echo "a directory: $BUILD_DIR"

build_target()
{
    TARGET=$1
    CONFIGURATION=$2
    echo building ${TARGET} - ${CONFIGURATION}
    XC="xcodebuild \
        -project ../NimbleCommander.xcodeproj \
        -scheme ${TARGET} \
        -configuration ${CONFIGURATION} \
        SYMROOT=${BUILD_DIR} \
        OBJROOT=${BUILD_DIR} \
        -parallelizeTargets \
        -quiet"
    BINARY_DIR=$($XC -showBuildSettings | grep " BUILT_PRODUCTS_DIR =" | sed -e 's/.*= *//')
    BINARY_NAME=$($XC -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//')
    BINARY_PATH=$BINARY_DIR/$BINARY_NAME
    $XC build
}

tests=(\
HabaneroUT \
ConfigUT \
UtilityUT \
VFSIconUnitTests \
VFSUT \
ViewerUT \
TermUT \
PanelUT \
NimbleCommanderUT \
)

configurations=(\
Debug \
Release \
)

for configuration in ${configurations[@]}; do
  for test in ${tests[@]}; do
    build_target $test $configuration
    $BINARY_PATH
  done
done

rm -rf ${BUILD_DIR}
