#!/bin/sh

set -e
set -o pipefail

# Check if clang-format is installed
if ! [ -x "$(command -v clang-format)" ] ; then
    echo 'clang-format is not found, aborting. Do brew install clang-format.'
    exit -1
fi

# Directory containing the files to format
DIRECTORY="$(dirname "$(realpath "$0")")/../Source"

# Get absolute path of DIRECTORY to ensure correct path comparison
ABS_DIRECTORY=$(realpath "$DIRECTORY")

# Iterate through all .h, .cpp, and .mm files in the specified directory
find "$ABS_DIRECTORY" -type f \( -name "*.h" -o -name "*.cpp" -o -name "*.mm" \) | while read file
do
    # Perform a dry run of clang-format to see if changes are needed
    if ! clang-format --dry-run -Werror "$file" &> /dev/null; then
        # Calculate relative path
        relative_path="${file#$ABS_DIRECTORY/}"
        echo "Formatting file: $relative_path"
        # If the dry run failed (implying formatting errors), apply clang-format
        clang-format -i "$file"
    fi
done
