#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/bz2.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b bzip2-1.0.8 --single-branch https://sourceware.org/git/bzip2.git
cd bzip2
make 
cd ../..

rm -rf ./include/
rm -rf ./built/
mkdir include
mkdir built

cp ${TMP_DIR}/bzip2/libbz2.a ./built/
cp ${TMP_DIR}/bzip2/bzlib.h ./include/

rm -rf ${TMP_DIR} 
