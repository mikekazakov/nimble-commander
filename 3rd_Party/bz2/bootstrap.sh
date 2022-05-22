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
make \
  CC=$(xcrun --sdk macosx --find cc) \
  CFLAGS="-arch x86_64 -arch arm64 -mmacosx-version-min=10.15 -fvisibility=hidden -flto -isysroot $(xcrun --sdk macosx --show-sdk-path)" \
  -j
cd ../..

rm -rf ./include/
rm -rf ./lib/
mkdir include
mkdir lib

cp ${TMP_DIR}/bzip2/libbz2.a ./lib/
cp ${TMP_DIR}/bzip2/bzlib.h ./include/

rm -rf ${TMP_DIR} 
