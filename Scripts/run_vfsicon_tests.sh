#!/bin/sh

set -o pipefail

build_target()
{
    TARGET=$1
    XC="xcodebuild \
        -project ../NimbleCommander.xcodeproj \
        -scheme $TARGET \
        -configuration Debug \
        -parallelizeTargets"    
    BINARY_DIR=$($XC -showBuildSettings | grep " BUILT_PRODUCTS_DIR =" | sed -e 's/.*= *//')
    BINARY_NAME=$($XC -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//')
    BINARY_PATH=$BINARY_DIR/$BINARY_NAME    
    $XC build
}

build_target VFSIconUnitTests
$BINARY_PATH

build_target VFSIconIntegrationTests
$BINARY_PATH
