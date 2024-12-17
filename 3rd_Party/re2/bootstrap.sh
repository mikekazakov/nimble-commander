#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/re2.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b 2024-07-02 --single-branch --depth=1 https://github.com/google/re2.git
cd re2
mkdir build_cmake
cd build_cmake
cmake \
  -D CMAKE_PREFIX_PATH="${CUR_DIR}/../abseil" \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_CXX_FLAGS="-fvisibility=hidden -flto -Os" \
  -D CMAKE_CXX_STANDARD="23" \
  -D BUILD_SHARED_LIBS=OFF \
  ..
make -j
cd ../../..

rm -rf ./include/
rm -rf ./lib/
mkdir include
mkdir include/re2
mkdir lib

cp ./re2.tmp/re2/build_cmake/libre2.a ./lib/
cp ./re2.tmp/re2/re2/*.h ./include/re2/

rm -rf ${TMP_DIR} 
