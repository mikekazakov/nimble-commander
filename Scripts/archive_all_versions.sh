#!/bin/sh
set -o pipefail

XC="xcodebuild \
     -project ../NimbleCommander.xcodeproj"

$XC -scheme NimbleCommander-NonMAS archive
$XC -scheme NimbleCommander-MAS-Free archive
$XC -scheme NimbleCommander-MAS-Paid archive

