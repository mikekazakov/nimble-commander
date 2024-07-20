#!/bin/sh

set -e
set -o pipefail

# Check if clang-format is installed
if ! [ -x "$(command -v clang-format)" ] ; then
    echo 'clang-format is not found, aborting. Do brew install clang-format.'
    exit -1
fi

# Directory containing the files to format
directory="$(dirname "$(realpath "$0")")/../Source"

# Get absolute path of DIRECTORY to ensure correct path comparison
abs_directory=$(realpath "$directory")

# Check if --check flag is provided
check_mode=0
if [ "$1" = "--check" ]; then
    echo "Dry run - only checking the formatting"
    check_mode=1
fi

# Flag to indicate if any file is not formatted correctly
any_file_not_formatted=0

# Collect all relevant files: all .h, .cpp, and .mm files in the specified directory
files=$(find "$abs_directory" -type f \( -name "*.h" -o -name "*.cpp" -o -name "*.mm" \))

# Iterate through  the files
while read -r file; do
    # Perform a dry run of clang-format to see if changes are needed
    if ! clang-format --dry-run -Werror "$file" &> /dev/null; then
        # Calculate relative path
        relative_path="${file#$abs_directory/}"
        echo "File not formatted correctly: $relative_path"
        
        if [ $check_mode -eq 1 ]; then
            # Check mode - only note that the formatting is incorrect
            any_file_not_formatted=1
        else            
            # If the dry run failed (implying formatting errors), apply clang-format
            echo "Formatting file: $relative_path"
            clang-format -i "$file"
        fi
    fi
done <<< "$files"

# Exit with a non-zero code if any file is not formatted correctly and --check flag is used
if [ $check_mode -eq 1 ]; then
    if [ $any_file_not_formatted -eq 1 ]; then
        echo "Code formatting check failed. Please run Scripts/run_clang_format.sh before submitting your code."
    fi
    exit $any_file_not_formatted
fi
