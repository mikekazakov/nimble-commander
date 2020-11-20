#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/lzma.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR}

git clone -b v5.2 --single-branch https://git.tukaani.org/xz.git
cd xz
mkdir build
cd build
cmake ..
make DESTDIR=./installed -j install
cd ../../..

rm -rf ./include/
rm -rf ./built/
mkdir include
mkdir built

cp ${TMP_DIR}/xz/build/liblzma.a ./built/
cp -R ${TMP_DIR}/xz/build/installed/usr/local/include/* ./include/

rm -rf ${TMP_DIR}
