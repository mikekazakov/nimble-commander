#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/abseil.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR}

git clone -b 20240722.0 --single-branch --depth=1 https://github.com/abseil/abseil-cpp.git
cd abseil-cpp
mkdir build_cmake
cd build_cmake
cmake \
  -D CMAKE_BUILD_TYPE=Release\
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_CXX_FLAGS="-fvisibility=hidden -flto -Os" \
  -D CMAKE_CXX_STANDARD="23" \
  -D CMAKE_INSTALL_PREFIX="${TMP_DIR}" \
  -D BUILD_SHARED_LIBS=OFF \
  -D BUILD_TESTING=OFF\
  ..
cmake --build . --target install -j

cd ../../..

rm -rf ./include/
rm -rf ./lib/
cp -r ./abseil.tmp/include .
cp -r ./abseil.tmp/lib .
rm -rf ./lib/pkgconfig

rm -rf ${TMP_DIR}
