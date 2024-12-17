#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/catch2.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b v3.7.1 --single-branch --depth=1 https://github.com/catchorg/Catch2

cd Catch2

cmake \
  -B build \
  -S . \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_CXX_FLAGS="-fvisibility=hidden" \
  -D CMAKE_CXX_STANDARD="23" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_INSTALL_PREFIX="${TMP_DIR}"

cmake --build build --target install -j

cd ../..

rm -rf ./include
rm -rf ./lib

cp -R ${TMP_DIR}/include .
cp -R ${TMP_DIR}/lib .
rm -rf ./lib/cmake

rm -rf ${TMP_DIR}
