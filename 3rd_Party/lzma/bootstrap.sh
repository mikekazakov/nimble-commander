#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/lzma.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR}

git clone -b v5.6.3 --single-branch --depth=1 https://github.com/tukaani-project/xz.git
cd xz
mkdir build
cd build
cmake \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_C_FLAGS="-fvisibility=hidden -flto -Os" \
  -D ENABLE_NLS=OFF \
  ..
make DESTDIR=./installed -j install
cd ../../..

rm -rf ./include/
rm -rf ./lib/
mkdir include
mkdir lib

cp ${TMP_DIR}/xz/build/liblzma.a ./lib/
cp -R ${TMP_DIR}/xz/build/installed/usr/local/include/* ./include/

rm -rf ${TMP_DIR}
