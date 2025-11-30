#!/bin/sh

set -e
set -o pipefail

if ! [ -x "$(command -v xcpretty)" ] ; then
    echo 'xcpretty is not found, aborting. (https://github.com/xcpretty/xcpretty)'
    exit -1
fi

if ! [ -x "$(command -v /opt/homebrew/opt/llvm/bin/clang-tidy)" ] ; then
    echo 'clang-tidy is not found, aborting. Do brew install llvm.'
    exit -1
fi

if ! [ -x "$(command -v jq)" ] ; then
    echo 'jq is not found, aborting. Do brew install jq.'
    exit -1
fi

# https://github.com/xcpretty/xcpretty/issues/48
export LC_CTYPE=en_US.UTF-8

# Determine the host architecture
HOST_ARCH=$(uname -m)

# Tools from LLVM
RUNTIDY=/opt/homebrew/opt/llvm/bin/run-clang-tidy
TIDY=/opt/homebrew/opt/llvm/bin/clang-tidy
APPLY=/opt/homebrew/opt/llvm/bin/clang-apply-replacements

# Get current directory
SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR=$(cd "$SCRIPTS_DIR/.." && pwd)

# Check if --check flag is provided
check_mode=0
if [ "$1" = "--check" ]; then
    echo "Dry run - only checking the clang-tidy rules"
    check_mode=1
fi

# Allocate a dir for build artifacts
BUILD_DIR="${SCRIPTS_DIR}/run_clang_tidy.tmp"
mkdir -p "${BUILD_DIR}"
xattr -w com.apple.xcode.CreatedByBuildSystem true "${BUILD_DIR}"

# A project to build
XCODEPROJ="${ROOT_DIR}/Source/NimbleCommander/NimbleCommander.xcodeproj"

echo Building the target "All"

# Common invocation of xcodebuild
XC="xcodebuild \
 -project ${XCODEPROJ} \
 -scheme All \
 -configuration Debug \
 -destination "platform=macOS,arch=${HOST_ARCH}" \
 SYMROOT=${BUILD_DIR} \
 OBJROOT=${BUILD_DIR} \
 -parallelizeTargets \
 ONLY_ACTIVE_ARCH=YES \
 COMPILER_INDEX_STORE_ENABLE=NO"

# Clean everything first
${XC} clean

# Build the target and capture the invocation command
$XC build | xcpretty -r json-compilation-database --output compile_commands.json

# Remove the "-ivfsstatcache path" flags that clang-tidy doesn't understand
sed -i '' 's/-ivfsstatcache[^\"]*\.sdkstatcache//g' "compile_commands.json"

# Extract all unique response files into an array, removing the '@' symbol
response_files=($(jq -r '.[].command' "compile_commands.json" | grep -o '@[^ ]*' | sed 's/^@//' | sort | uniq))
# Process each response file
for file in "${response_files[@]}"; do
  # Use sed to modify the file in-place and remove -fmodules and -fmodules-cache-path=...
  sed -i '' -E "s/'?-fmodules-cache-path=[^ ]+'?//g; s/'?-fmodules'?//g" "$file"
done

# Find all files ending with "-Swift.h" and search for "@import" statements
find "$BUILD_DIR" -type f -name '*-Swift.h' | while read file; do
  # Use sed to comment out the lines in place
  sed -i '' -E 's/^(@import [A-Za-z]+;)/\/\/ \1/' "$file"
done

# Log file to capture the output of run-clang-tidy
LOG_FILE="${BUILD_DIR}/run-clang-tidy.log"

# Run clang-tidy in parallel via run-clang-tidy
if [ $check_mode -eq 1 ]; then
    echo "Running in check mode. No fixes will be applied."
    ${RUNTIDY} \
     -p ${SCRIPTS_DIR} \
     -clang-tidy-binary ${TIDY} \
     -clang-apply-replacements-binary ${APPLY} \
     -j $(sysctl -n hw.activecpu) \
     -use-color 1 \
     "${ROOT_DIR}/Source/.*" 2>&1 | tee ${LOG_FILE}
else
    echo "Running in fix mode. Fixes will be applied."
    ${RUNTIDY} \
     -p ${SCRIPTS_DIR} \
     -clang-tidy-binary ${TIDY} \
     -clang-apply-replacements-binary ${APPLY} \
     -j $(sysctl -n hw.activecpu) \
     -use-color 1 \
     -fix \
     -format \
     "${ROOT_DIR}/Source/.*" 2>&1 | tee ${LOG_FILE}
fi

# Exit with non-zero if in check mode and any issues were found
if [ $check_mode -eq 1 ]; then
    if grep -q "warning:" ${LOG_FILE} || grep -q "error:" ${LOG_FILE}; then
        echo "Clang-tidy check failed. Please run Scripts/run_clang_tidy.sh before submitting your code."
        exit 1
    else
        echo "Clang-tidy check passed."
        exit 0
    fi
fi
