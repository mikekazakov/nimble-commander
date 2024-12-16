#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/libarchive.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

git clone -b v3.7.7 --depth 1 https://github.com/libarchive/libarchive.git

cd libarchive

git apply ../../*.patch

cmake \
  -D CMAKE_TESTING_ENABLED=Off \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_C_FLAGS="-fvisibility=hidden -flto" \
  -D CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -D CMAKE_OSX_DEPLOYMENT_TARGET="10.15" \
  -D CMAKE_IGNORE_PREFIX_PATH=/usr/local \
  -D BUILD_SHARED_LIBS="OFF" \
  -D ENABLE_LIBB2="OFF" \
  -D ZLIB_INCLUDE_DIR=${CUR_DIR}/../z/include \
  -D ZLIB_LIBRARY=${CUR_DIR}/../z/lib/libz.a \
  -D BZIP2_INCLUDE_DIR=${CUR_DIR}/../bz2/include \
  -D BZIP2_LIBRARIES=${CUR_DIR}/../bz2/lib/libbz2.a \
  -D LIBLZMA_INCLUDE_DIR=${CUR_DIR}/../lzma/include \
  -D LIBLZMA_LIBRARY=${CUR_DIR}/../lzma/lib/liblzma.a \
  -D ZSTD_INCLUDE_DIR=${CUR_DIR}/../zstd/include \
  -D ZSTD_LIBRARY=${CUR_DIR}/../zstd/lib/libzstd.a \
  -D LZ4_INCLUDE_DIR=${CUR_DIR}/../lz4/include \
  -D LZ4_LIBRARY=${CUR_DIR}/../lz4/lib/liblz4.a \
  -D ENABLE_LZO="ON" \
  -D LZO2_INCLUDE_DIR=${CUR_DIR}/../lzo/include \
  -D LZO2_LIBRARY=${CUR_DIR}/../lzo/lib/liblzo2.a \
  -D ENABLE_ICONV="ON" \
  .
make -j

ctest \
  -E "libarchive_test_gnutar_filename_encoding_EUCJP_CP932|\
libarchive_test_read_format_cab_filename|\
libarchive_test_read_format_lha_filename|\
libarchive_test_read_format_zip_filename_CP932_eucJP|\
libarchive_test_read_format_zip_filename_CP932_CP932|\
libarchive_test_sparse_basic|libarchive_test_ustar_filename_encoding_EUCJP_CP932" \
  --test-dir .

cd ./../../
rm -rf ./include/
rm -rf ./lib/

mkdir include
mkdir include/libarchive
mkdir lib

cp ./libarchive.tmp/libarchive/libarchive/archive.h ./include/libarchive/
cp ./libarchive.tmp/libarchive/libarchive/archive_entry.h ./include/libarchive/
cp ./libarchive.tmp/libarchive/libarchive/libarchive.a ./lib

rm -rf ${TMP_DIR}
