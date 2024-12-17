#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/openssl.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR}

git clone -b OpenSSL_1_1_1w --single-branch --depth 1 https://github.com/openssl/openssl.git openssl.x64
cp -r openssl.x64 openssl.arm64

CFLAGS="-mmacosx-version-min=10.15 -fvisibility=hidden -flto -Os -isysroot $(xcrun --sdk macosx --show-sdk-path)"

cd openssl.x64
arch -arch x86_64 ./config \
  --with-zlib-include=../../../z/include \
  --with-zlib-lib=../../../z/built \
  --prefix=${CUR_DIR}/openssl.tmp/installed.x64/ \
  no-shared \
  no-asm \
  zlib \
  enable-md2 \
  enable-rc5 \
  CFLAGS="${CFLAGS}"
make -j
make -j test
make -j install

cd ../openssl.arm64
arch -arch arm64 ./config \
  --with-zlib-include=../../../z/include \
  --with-zlib-lib=../../../z/built \
  --prefix=${CUR_DIR}/openssl.tmp/installed.arm64/ \
  no-shared \
  no-asm \
  zlib \
  enable-md2 \
  enable-rc5 \
  CFLAGS="${CFLAGS}"
make -j
make -j test
make -j install

cd ..
lipo -create ./installed.arm64/lib/libcrypto.a ./installed.x64/lib/libcrypto.a -output ./libcrypto.a
lipo -create ./installed.arm64/lib/libssl.a    ./installed.x64/lib/libssl.a    -output ./libssl.a

cd ..
rm -rf ./include/
rm -rf ./lib/
mkdir include
mkdir lib

cp ${TMP_DIR}/*.a ./lib/
cp -R ${TMP_DIR}/installed.x64/include/* ./include/

rm -rf ${TMP_DIR}
