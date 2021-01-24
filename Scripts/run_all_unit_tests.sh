#!/bin/sh

set -o pipefail

build_target()
{
    TARGET=$1
    CONFIGURATION=$2
    echo building ${TARGET} - ${CONFIGURATION}
    XC="xcodebuild \
        -project ../NimbleCommander.xcodeproj \
        -scheme ${TARGET} \
        -configuration ${CONFIGURATION} \
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
