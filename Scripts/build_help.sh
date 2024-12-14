#!/bin/sh

set -e
set -o pipefail

if ! [ -x "$(command -v pandoc)" ] ; then
    echo 'pandoc is not found, aborting. do brew install pandoc'
    exit -1
fi

if ! [ -x "$(command -v xelatex)" ] ; then
    echo 'xelatex is not found, aborting. do brew install basictex'
    exit -1
fi

# get current directory
SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

BUILD_DIR="${SCRIPTS_DIR}/build_help.tmp"
mkdir -p "${BUILD_DIR}"

cd ../Docs

pandoc \
 ./Help.md \
 --pdf-engine=xelatex \
 --fail-if-warnings=true \
 -f markdown-implicit_figures \
 --toc \
 -V toc-title:"Nimble Commander User Guide" \
 -V colorlinks=true \
 -V linkcolor=blue \
 -V urlcolor=blue \
 -V toccolor=blue \
 -V geometry:margin=1in \
 -o ${BUILD_DIR}/Help.pdf
