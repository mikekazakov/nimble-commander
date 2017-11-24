#!/bin/sh
xcodebuild -project NimbleCommander.xcodeproj -scheme NimbleCommander-Unsigned -configuration Debug -quiet build
APP_DIR=$(xcodebuild -project NimbleCommander.xcodeproj -scheme NimbleCommander-Unsigned -configuration Debug -showBuildSettings | grep " BUILT_PRODUCTS_DIR =" | sed -e 's/.*= *//' )
APP_NAME=$(xcodebuild -project NimbleCommander.xcodeproj -scheme NimbleCommander-Unsigned -configuration Debug -showBuildSettings | grep " FULL_PRODUCT_NAME =" | sed -e 's/.*= *//' )
APP_PATH=$APP_DIR/$APP_NAME
open -a $APP_PATH
