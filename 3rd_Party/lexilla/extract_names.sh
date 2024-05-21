#!/bin/bash

# Check if the filename is passed as an argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 filename"
    exit 1
fi

# File to read from
input_file="$1"

# Temporary files to store names and values
names_file=$(mktemp)
values_file=$(mktemp)

# Use grep to find lines starting with #define and containing SCE_
# Use awk to print the second and third fields which contain the name and value
grep '^#define SCE_' "$input_file" | awk '{print $2, $3}' > $names_file

# Extract names and create string literals
awk '{print "\"" $1 "\","}' $names_file > $values_file

# Print the names array
echo "#pragma once"
echo "namespace Lexilla {"
echo "constinit const char* g_SCENames[] = {"
cat $values_file
echo "};"

# Extract values
awk '{print $2 ","}' $names_file > $values_file

# Print the values array
echo "constinit int g_SCEValues[] = {"
cat $values_file
echo "};"
echo "}"

# Clean up temporary files
rm $names_file $values_file

