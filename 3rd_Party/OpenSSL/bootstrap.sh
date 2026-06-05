#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/openssl.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR}

git clone -b openssl-3.5.5 --single-branch --depth 1 https://github.com/openssl/openssl.git openssl.x64
cp -r openssl.x64 openssl.arm64

# NB! No -fvisibility=hidden neither -flto passed, since OpenSSL3 is quite a snowflake...
CFLAGS="-mmacosx-version-min=11.0 -Os -isysroot $(xcrun --sdk macosx --show-sdk-path)"

cd openssl.x64
arch -arch x86_64 ./config \
  --with-zlib-include=../../../z/include \
  --with-zlib-lib=../../../z/lib \
  --with-zstd-include=../../../zstd/include \
  --with-zstd-lib=../../../zstd/lib \
  --prefix=${CUR_DIR}/openssl.tmp/installed.x64/ \
  no-shared \
  no-asm \
  zlib \
  enable-zstd \
  enable-md2 \
  enable-rc5 \
  CFLAGS="${CFLAGS}"
make -j4
make -j4 test
make -j4 install

cd ../openssl.arm64
arch -arch arm64 ./config \
  --with-zlib-include=../../../z/include \
  --with-zlib-lib=../../../z/lib \
  --with-zstd-include=../../../zstd/include \
  --with-zstd-lib=../../../zstd/lib \
  --prefix=${CUR_DIR}/openssl.tmp/installed.arm64/ \
  no-shared \
  no-asm \
  zlib \
  enable-zstd \
  enable-md2 \
  enable-rc5 \
  CFLAGS="${CFLAGS}"
make -j4
make -j4 test
make -j4 install

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
