#!/bin/sh

set -x
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
BUILD_DIR="${SCRIPTS_DIR}/build_nightly.tmp"
mkdir -p "${BUILD_DIR}"

# all builds paths will be relative to ROOT_DIR
ROOT_DIR=$(cd "$SCRIPTS_DIR/.." && pwd)

XCODEPROJ="../Source/NimbleCommander/NimbleCommander.xcodeproj"

PBUDDY=/usr/libexec/PlistBuddy

if type -p /usr/local/bin/ccache >/dev/null 2>&1; then
    echo Using ccache
    export CCACHE_BASEDIR="${ROOT_DIR}"
    export CCACHE_SLOPPINESS=time_macros,include_file_mtime,include_file_ctime,file_stat_matches
    export CC="${SCRIPTS_DIR}/ccache-clang"
    export CXX="${SCRIPTS_DIR}/ccache-clang++"
fi

XC="xcodebuild \
 -project ${XCODEPROJ} \
 -scheme NimbleCommander-NonMAS \
 -configuration Release \
 CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
 SYMROOT=${BUILD_DIR} \
 OBJROOT=${BUILD_DIR} \
 OTHER_CFLAGS=\"-fdebug-prefix-map=${ROOT_DIR}=.\""

APP_DIR=$($XC -showBuildSettings | grep " BUILT_PRODUCTS_DIR =" | sed -e 's/.*= *//' )
APP_NAME=$($XC -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//' )
APP_PATH=$APP_DIR/$APP_NAME

$XC build | xcpretty

cp -R "${APP_PATH}" ./

# Sign the app with timestamps
codesign \
 --verbose \
 --sign 'Developer ID Application' \
 --force \
 --deep \
 --timestamp \
 --options runtime \
 "./${APP_NAME}/Contents/Library/LaunchServices/info.filesmanager.Files.PrivilegedIOHelperV2"

codesign \
 --verbose \
 --sign 'Developer ID Application' \
 --force \
 --deep \
 --timestamp \
 --options runtime \
 "./${APP_NAME}"

# Extract the version number and the build number
VERSION=$( $PBUDDY -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" )
BUILD=$( $PBUDDY -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist" )
DMG_NAME="nimble-commander-nightly-${VERSION}(${BUILD}).dmg"

create-dmg \
 --volname "Nimble Commander Nightly" \
 --window-pos 200 200 \
 --window-size 610 386 \
 --background "dmg/background.png" \
 --text-size 12 \
 --icon-size 128 \
 --icon "${APP_NAME}" 176 192 \
 --app-drop-link 432 192 \
 --codesign "Developer ID Application: Mikhail Kazakov (AC5SJT236H)" \
 "${DMG_NAME}" \
 "${APP_NAME}"

# Upload the built dmg into Apple's notary service
xcrun notarytool submit ${DMG_NAME} --keychain-profile AC_PASSWORD --wait

# Finally, staple the dmg
xcrun stapler staple "${DMG_NAME}"
