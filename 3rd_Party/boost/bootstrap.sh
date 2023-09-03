#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/boost.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

wget https://boostorg.jfrog.io/artifactory/main/release/1.83.0/source/boost_1_83_0.tar.gz
tar -xf boost_1_83_0.tar.gz
cd boost_1_83_0
#./bootstrap.sh --with-libraries=filesystem,system,container
#
#CFLAGS="-Os -fvisibility=hidden -fvisibility-inlines-hidden -mmacosx-version-min=10.15 -arch x86_64 -arch arm64 -isysroot $(xcrun --sdk macosx --show-sdk-path)"
#
#./b2 \
#  cflags="${CFLAGS}" \
#  cxxflags="${CFLAGS} -std=c++20" \
#  link=static \
#  lto=on
 
cd ../..

rm -rf ./include/
#rm -rf ./lib/
mkdir include
mkdir include/boost
#mkdir lib

B=${TMP_DIR}/boost_1_83_0/boost

cp -R \
 ${B}/algorithm \
 ${B}/align \
 ${B}/asio \
 ${B}/assert \
 ${B}/bind \
 ${B}/concept \
 ${B}/config \
 ${B}/container \
 ${B}/container_hash \
 ${B}/core \
 ${B}/describe \
 ${B}/detail \
 ${B}/exception \
 ${B}/filesystem \
 ${B}/function \
 ${B}/function_types \
 ${B}/functional \
 ${B}/fusion \
 ${B}/integer \
 ${B}/intrusive \
 ${B}/io \
 ${B}/iterator \
 ${B}/move \
 ${B}/mp11 \
 ${B}/mpl \
 ${B}/optional \
 ${B}/predef \
 ${B}/preprocessor \
 ${B}/process \
 ${B}/random \
 ${B}/range \
 ${B}/smart_ptr \
 ${B}/system \
 ${B}/tti \
 ${B}/type_index \
 ${B}/type_traits \
 ${B}/utility \
 ${B}/uuid \
 ${B}/winapi \
 ./include/boost/

cp -R \
 ${B}/assert.hpp \
 ${B}/blank.hpp \
 ${B}/blank_fwd.hpp \
 ${B}/cerrno.hpp \
 ${B}/concept_check.hpp \
 ${B}/config.hpp \
 ${B}/cstdint.hpp \
 ${B}/current_function.hpp \
 ${B}/function.hpp \
 ${B}/function_equal.hpp \
 ${B}/get_pointer.hpp \
 ${B}/integer.hpp \
 ${B}/integer_fwd.hpp \
 ${B}/integer_traits.hpp \
 ${B}/io_fwd.hpp \
 ${B}/limits.hpp \
 ${B}/mem_fn.hpp \
 ${B}/next_prior.hpp \
 ${B}/none.hpp \
 ${B}/none_t.hpp \
 ${B}/optional.hpp \
 ${B}/process.hpp \
 ${B}/static_assert.hpp \
 ${B}/throw_exception.hpp \
 ${B}/token_functions.hpp \
 ${B}/token_iterator.hpp \
 ${B}/tokenizer.hpp \
 ${B}/type.hpp \
 ${B}/type_index.hpp \
 ${B}/utility.hpp \
 ${B}/version.hpp \
 ./include/boost/

#cp -R ${TMP_DIR}/boost_1_83_0/boost ./include/
#cd ./include/boost/

# rm -rf phoenix geometry math atomic

#cd -





#cp ${TMP_DIR}/boost_1_83_0/stage/lib/*.a ./lib/

rm -rf ${TMP_DIR}
