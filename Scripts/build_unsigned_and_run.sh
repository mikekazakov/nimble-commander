#!/bin/sh
XC="xcodebuild \
    -project ../NimbleCommander.xcodeproj \
    -scheme NimbleCommander-Unsigned \
    -configuration Debug"

APP_DIR=$($XC -showBuildSettings | grep " BUILT_PRODUCTS_DIR =" | sed -e 's/.*= *//' )
APP_NAME=$($XC -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//' )
APP_PATH=$APP_DIR/$APP_NAME

$XC build
open -a $APP_PATH
