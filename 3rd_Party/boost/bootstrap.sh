#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/boost.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

wget https://boostorg.jfrog.io/artifactory/main/release/1.79.0/source/boost_1_79_0.tar.gz
tar -xf boost_1_79_0.tar.gz
cd boost_1_79_0
./bootstrap.sh --with-libraries=filesystem,system,container

./b2 \
  cflags="-Os -fvisibility=hidden -fvisibility-inlines-hidden -mmacosx-version-min=10.15 -arch x86_64 -arch arm64" \
  cxxflags="-Os -fvisibility=hidden -fvisibility-inlines-hidden -std=c++20 -mmacosx-version-min=10.15 -arch x86_64 -arch arm64" \
  link=static \
  lto=on
 
cd ../..

rm -rf ./include/
rm -rf ./lib/
mkdir include
mkdir lib

cp -R ${TMP_DIR}/boost_1_79_0/boost ./include/
cp ${TMP_DIR}/boost_1_79_0/stage/lib/*.a ./lib/

rm -rf ${TMP_DIR}
