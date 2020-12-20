#!/bin/sh

set -o pipefail

build_target()
{
    TARGET=$1
    XC="xcodebuild \
        -project ../NimbleCommander.xcodeproj \
        -scheme $TARGET \
        -configuration Debug \
        -parallelizeTargets \
        -quiet"
    BINARY_DIR=$($XC -showBuildSettings | grep " BUILT_PRODUCTS_DIR =" | sed -e 's/.*= *//')
    BINARY_NAME=$($XC -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//')
    BINARY_PATH=$BINARY_DIR/$BINARY_NAME
    echo building ${TARGET}
    $XC build
}

build_target HabaneroUT
$BINARY_PATH

build_target ConfigUT
$BINARY_PATH

build_target UtilityUT
$BINARY_PATH

build_target VFSIconUnitTests
$BINARY_PATH

build_target VFSIconIntegrationTests
$BINARY_PATH

build_target VFSUT
$BINARY_PATH

build_target VFSIT
$BINARY_PATH

build_target ViewerUT
$BINARY_PATH

build_target OperationsUT
$BINARY_PATH

build_target OperationsIT
$BINARY_PATH

build_target TermUT
$BINARY_PATH

build_target TermIT
$BINARY_PATH

build_target PanelUT
$BINARY_PATH

build_target NimbleCommanderUT
$BINARY_PATH
