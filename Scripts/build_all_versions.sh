#!/bin/sh
set -o pipefail

XC="xcodebuild -project ../NimbleCommander.xcodeproj"

$XC clean

SCHEMES="NimbleCommander-Unsigned NimbleCommander-NonMAS NimbleCommander-MAS-Free NimbleCommander-MAS-Paid"
CONFIGURATIONS="Debug Release"
for SCHEME in $SCHEMES
do
    for CONFIGURATION in $CONFIGURATIONS
    do
        CMD="$XC -scheme $SCHEME -configuration $CONFIGURATION"
        echo "Command: $CMD"
        $CMD build | xcpretty
        if [ $? -ne 0 ]
        then
            exit $? 
        fi
    done 
    if [ $? -ne 0 ]
    then
        exit $? 
    fi
done
if [ $? -ne 0 ]
then
    exit $? 
fi
