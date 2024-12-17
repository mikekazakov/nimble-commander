#!/bin/sh

set -e
set -o pipefail

if ! [ -x "$(command -v xcpretty)" ] ; then
    echo 'xcpretty is not found, aborting. (https://github.com/xcpretty/xcpretty)'
    exit -1
fi

# https://github.com/xcpretty/xcpretty/issues/48
export LC_CTYPE=en_US.UTF-8

# Set up the paths to the sources and artifacts
SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR=$(cd "$SCRIPTS_DIR/.." && pwd)
XCODEPROJ="${ROOT_DIR}/Source/NimbleCommander/NimbleCommander.xcodeproj"
BUILD_DIR="${SCRIPTS_DIR}/build_mas_archive.tmp"
BUILT_PATH="${BUILD_DIR}/built"
mkdir -p "${BUILD_DIR}"

# Build Help.pdf and copy it into the NC sources
${SCRIPTS_DIR}/build_help.sh
cp -f "${SCRIPTS_DIR}/build_help.tmp/Help.pdf" "${ROOT_DIR}/Source/NimbleCommander/NimbleCommander/Resources/Help.pdf"

# Gather common flags in the XC variable
XC="xcodebuild \
 -project ${XCODEPROJ} \
 -scheme NimbleCommander-MAS \
 -configuration Release \
 OTHER_CFLAGS=\"-fdebug-prefix-map=${ROOT_DIR}=.\""

# Build and archive the project
$XC archive | xcpretty

## Done!
