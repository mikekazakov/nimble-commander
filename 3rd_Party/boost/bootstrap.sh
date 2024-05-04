#!/bin/sh
set -o pipefail
set -o xtrace
set -e

CUR_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
TMP_DIR=${CUR_DIR}/boost.tmp

mkdir ${TMP_DIR}
cd ${TMP_DIR} 

wget https://boostorg.jfrog.io/artifactory/main/release/1.85.0/source/boost_1_85_0.tar.gz
tar -xf boost_1_85_0.tar.gz

cd ..

rm -rf ./include/
mkdir include
mkdir include/boost

B=${TMP_DIR}/boost_1_85_0/boost

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
 ${B}/range \
 ${B}/smart_ptr \
 ${B}/system \
 ${B}/tti \
 ${B}/type_index \
 ${B}/type_traits \
 ${B}/utility \
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

rm -rf ${TMP_DIR}
