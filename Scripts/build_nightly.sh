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

PBUDDY=/usr/libexec/PlistBuddy

# Set up the paths to the sources and artifacts
SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR=$(cd "$SCRIPTS_DIR/.." && pwd)
XCODEPROJ="${ROOT_DIR}/Source/NimbleCommander/NimbleCommander.xcodeproj"
BUILD_DIR="${SCRIPTS_DIR}/build_nightly.tmp"
ARCHIVE_PATH="${BUILD_DIR}/NC_NonMAS.xcarchive"
BUILT_PATH="${BUILD_DIR}/built"
mkdir -p "${BUILD_DIR}"
mkdir -p "${ARCHIVE_PATH}"

# Build Help.pdf and copy it into the NC sources
${SCRIPTS_DIR}/build_help.sh
cp -f "${SCRIPTS_DIR}/build_help.tmp/Help.pdf" "${ROOT_DIR}/Source/NimbleCommander/NimbleCommander/Resources/Help.pdf"

# Gather common flags in the XC variable
XC="xcodebuild \
 -project ${XCODEPROJ} \
 -scheme NimbleCommander-NonMAS \
 -configuration Release \
 OTHER_CFLAGS=\"-fdebug-prefix-map=${ROOT_DIR}=.\""

# Build and archive the project
$XC -archivePath ${ARCHIVE_PATH} archive | xcpretty

# Export a signed version
xcodebuild -exportArchive \
 -archivePath $ARCHIVE_PATH \
 -exportPath $BUILT_PATH \
 -exportOptionsPlist export_options.plist

# Extract the version number and the build number
APP_NAME=$($XC -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//' )
APP_PATH="${BUILT_PATH}/${APP_NAME}"
VERSION=$( $PBUDDY -c "Print CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist" )
BUILD=$( $PBUDDY -c "Print CFBundleVersion" "${APP_PATH}/Contents/Info.plist" )
DMG_NAME="nimble-commander-nightly-${VERSION}(${BUILD}).dmg"

# Wrap the built application into a .dmg disk image
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
 "${APP_PATH}"

# Upload the built dmg into Apple's notary service and wait for the response
xcrun notarytool submit ${DMG_NAME} --keychain-profile AC_PASSWORD --wait

# Finally, staple the dmg
xcrun stapler staple "${DMG_NAME}"

# Done!
