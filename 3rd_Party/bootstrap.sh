#!/bin/sh
set -o pipefail
set -o xtrace
set -e

# pour yourself some coffee and relax, it'll take a while
./z/bootstrap.sh
./bz2/bootstrap.sh
./lzma/bootstrap.sh
./zstd/bootstrap.sh
./lz4/bootstrap.sh
./lzo/bootstrap.sh
./openssl/bootstrap.sh
./libssh2/bootstrap.sh
./libcurl/bootstrap.sh
./pugixml/bootstrap.sh
./boost/bootstrap.sh
./libarchive/bootstrap.sh
./fmt/bootstrap.sh
./spdlog/bootstrap.sh
./googletest/bootstrap.sh
./AppAuth/bootstrap.sh
./Sparkle/bootstrap.sh
./LetsMove/bootstrap.sh
./frozen/bootstrap.sh
./pstld/bootstrap.sh
./abseil/bootstrap.sh
./re2/bootstrap.sh
./libcxxbackport/bootstrap.sh
./lexilla/bootstrap.sh
./nlohmann/bootstrap.sh
./unordered_dense/bootstrap.sh
./Catch2/bootstrap.sh
./rapidjson/bootstrap.sh
