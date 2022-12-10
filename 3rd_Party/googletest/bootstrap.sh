#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/gtest.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b release-1.12.1 --single-branch https://github.com/google/googletest.git
cd googletest

mkdir build && cd build
cmake \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_CXX_FLAGS="-fvisibility=hidden -flto -Os" \
  ..
make -j

cd ../../..

rm -rf ./include/
rm -rf ./lib/
mkdir include
mkdir lib

cp ${TMP_DIR}/googletest/build/lib/*.a ./lib/
cp -R ${TMP_DIR}/googletest/googlemock/include/* ./include/
cp -R ${TMP_DIR}/googletest/googletest/include/* ./include/

rm -rf ${TMP_DIR} 
