#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/spdlog.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b v1.8.1 --single-branch https://github.com/gabime/spdlog.git
cd spdlog

mkdir build && cd build

cmake \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_CXX_FLAGS="-fvisibility=hidden -flto -Os" \
  ..
make -j

cd ./../../../
rm -rf ./include/
rm -rf ./lib/

mkdir include
mkdir lib
cp -R ${TMP_DIR}/spdlog/include/spdlog ./include/
cp ${TMP_DIR}/spdlog/build/libspdlog.a ./lib/

rm -rf ${TMP_DIR}

