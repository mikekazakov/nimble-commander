#!/bin/sh
set -o pipefail

XC="xcodebuild \
     -project ../NimbleCommander.xcodeproj \
     -scheme NimbleCommander-NonMAS \
     -configuration Debug"

$XC clean
$XC build

APP_DIR=$($XC -showBuildSettings | grep " BUILT_PRODUCTS_DIR =" | sed -e 's/.*= *//' )
APP_NAME=$($XC -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//' )
APP_PATH=$APP_DIR/$APP_NAME

PBUDDY=/usr/libexec/PlistBuddy
VERSION=$( $PBUDDY -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" )
BUILD=$( $PBUDDY -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist" )

ZIPNAME=nimble-commander-$VERSION\($BUILD\).zip
rm $HOME/Desktop/$ZIPNAME

cd "$APP_DIR"
zip $HOME/Desktop/$ZIPNAME -r --symlinks "$APP_NAME"
