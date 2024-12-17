#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/curl.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b curl-8_11_1 --single-branch --depth=1 https://github.com/curl/curl.git

cd curl

mkdir build
cd build

cmake \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_C_FLAGS="-fvisibility=hidden -flto" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_IGNORE_PATH="/usr/local;/opt/homebrew;/opt/homebrew/include" \
  -D CURL_USE_SECTRANSP="ON" \
  -D CURL_USE_LIBSSH="OFF" \
  -D CURL_USE_LIBSSH2="OFF" \
  -D CURL_DISABLE_LDAP="ON" \
  -D CURL_ZLIB="ON" \
  -D BUILD_STATIC_LIBS="ON" \
  -D BUILD_SHARED_LIBS="OFF" \
  -D ZLIB_INCLUDE_DIR=${CUR_DIR}/../z/include \
  -D ZLIB_LIBRARY=${CUR_DIR}/../z/lib/libz.a \
  ..
make -j

cd ./../../../
rm -rf ./include/
rm -rf ./lib/

mkdir include
mkdir include/curl
mkdir lib

cp ./curl.tmp/curl/include/curl/*.h ./include/curl/
cp ./curl.tmp/curl/build/lib/libcurl.a ./lib/
cp ./curl.tmp/curl/build/lib/curl_config.h ./include/curl/

rm -rf ${TMP_DIR} 
