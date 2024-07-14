#!/bin/sh

set -e
set -o pipefail

if ! [ -x "$(command -v xcpretty)" ] ; then
    echo 'xcpretty is not found, aborting. (https://github.com/xcpretty/xcpretty)'
    exit -1
fi

if ! [ -x "$(command -v create-dmg)" ] ; then
    echo 'create-dmg is not found, aborting. (https://github.com/create-dmg/create-dmg)'
    exit -1
fi

# https://github.com/xcpretty/xcpretty/issues/48
export LC_CTYPE=en_US.UTF-8

# get current directory
SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# allocate a dir for build artifacts
BUILD_DIR="${SCRIPTS_DIR}/build_unsigned.tmp"
mkdir "${BUILD_DIR}"

# all builds paths will be relative to ROOT_DIR
ROOT_DIR=$(cd "$SCRIPTS_DIR/.." && pwd)
XCODEPROJ="../Source/NimbleCommander/NimbleCommander.xcodeproj"
PBUDDY=/usr/libexec/PlistBuddy

# Build Help.pdf and copy it into the NC sources
${SCRIPTS_DIR}/build_help.sh
cp -f "${SCRIPTS_DIR}/build_help.tmp/Help.pdf" "${ROOT_DIR}/Source/NimbleCommander/NimbleCommander/Resources/Help.pdf"

XC="xcodebuild \
 -project ${XCODEPROJ} \
 -scheme NimbleCommander-NonMAS \
 -configuration Release \
 CODE_SIGNING_ALLOWED=NO \
 CODE_SIGN_IDENTITY= \
 DEVELOPMENT_TEAM= \
 PROVISIONING_PROFILE_SPECIFIER= \
 CODE_SIGN_ENTITLEMENTS= \
 SYMROOT=${BUILD_DIR} \
 OBJROOT=${BUILD_DIR} \
 OTHER_CFLAGS=\"-fdebug-prefix-map=${ROOT_DIR}=.\""

APP_DIR=$($XC -showBuildSettings | grep " BUILT_PRODUCTS_DIR =" | sed -e 's/.*= *//' )
APP_NAME=$($XC -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//' )
APP_PATH=$APP_DIR/$APP_NAME

$XC build | xcpretty

cp -R "${APP_PATH}" ./

VERSION=$( $PBUDDY -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" )
BUILD=$( $PBUDDY -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist" )

create-dmg \
 --volname "Nimble Commander Unsigned" \
 --window-pos 200 200 \
 --window-size 610 386 \
 --background "dmg/background.png" \
 --text-size 12 \
 --icon-size 128 \
 --icon "${APP_NAME}" 176 192 \
 --app-drop-link 432 192 \
 "nimble-commander-unsigned-${VERSION}(${BUILD}).dmg" \
 "${APP_NAME}"
