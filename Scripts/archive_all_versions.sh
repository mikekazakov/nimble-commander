#!/bin/sh
set -o pipefail

XC="xcodebuild \
     -project ../NimbleCommander.xcodeproj"

$XC -scheme NimbleCommander-NonMAS archive | xcpretty
$XC -scheme NimbleCommander-MAS-Free archive | xcpretty
$XC -scheme NimbleCommander-MAS-Paid archive | xcpretty

