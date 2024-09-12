#!/bin/sh

set -e
set -o pipefail

if ! [ -x "$(command -v xcpretty)" ] ; then
    echo 'xcpretty is not found, aborting. (https://github.com/xcpretty/xcpretty)'
    exit -1
fi

# https://github.com/xcpretty/xcpretty/issues/48
export LC_CTYPE=en_US.UTF-8

# a project to build
XCODEPROJ="../Source/NimbleCommander/NimbleCommander.xcodeproj"

# list of targets to build
uts=$(xcodebuild -project ${XCODEPROJ} -list | awk -v word="Schemes:" 'BEGIN {found=0} found {if ($0 ~ /UT$/) print} $0 ~ word {found=1}' | sed 's/^[[:space:]]*//')
its=$(xcodebuild -project ${XCODEPROJ} -list | awk -v word="Schemes:" 'BEGIN {found=0} found {if ($0 ~ /IT$/) print} $0 ~ word {found=1}' | sed 's/^[[:space:]]*//')
others=("NimbleCommander-Unsigned")
targets=("${uts[@]}" "${its[@]}" "${others[@]}")
echo Building these targets: ${targets[@]}

# build each target
for target in ${targets[@]}; do
    xcodebuild -project ${XCODEPROJ} -scheme ${target} -configuration Debug | xcpretty
done

# clean afterwards to save space on gh runners
for target in ${targets[@]}; do
    xcodebuild clean -project ${XCODEPROJ} -scheme ${target} -configuration Debug
done
