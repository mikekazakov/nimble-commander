#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/libssh2.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b libssh2-1.11.1 --single-branch https://github.com/libssh2/libssh2.git
cd libssh2

cmake \
  -B build \
  -S . \
  -D CMAKE_PREFIX_PATH="${CUR_DIR}/../z;${CUR_DIR}/../OpenSSL" \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_C_FLAGS="-fvisibility=hidden -flto -Os -DLIBSSH2_DSA_ENABLE" \
  -D BUILD_STATIC_LIBS=ON \
  -D BUILD_SHARED_LIBS=OFF \
  -D CRYPTO_BACKEND=OpenSSL \
  -D ENABLE_ZLIB_COMPRESSION=ON \
  -D RUN_DOCKER_TESTS=OFF \
  -D RUN_SSHD_TESTS=OFF

cmake --build build -j
ctest \
  --test-dir build \
  --output-on-failure \
  --exclude-regex test_auth_pubkey_ok_dsa

cd ./../../
rm -rf ./include/
rm -rf ./lib/

mkdir include
mkdir lib
cp ${TMP_DIR}/libssh2/include/*.h ./include/
cp ${TMP_DIR}/libssh2/build/src/libssh2.a ./lib/

rm -rf ${TMP_DIR} 
