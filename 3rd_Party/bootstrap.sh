#!/bin/sh
set -o pipefail
set -o xtrace
set -e

# pour yourself some coffee and relax, it'll take a while
export MACOSX_DEPLOYMENT_TARGET="10.15"
./z/bootstrap.sh
./bz2/bootstrap.sh
./lzma/bootstrap.sh
./openssl/bootstrap.sh
./libcurl/bootstrap.sh
./libssh2/bootstrap.sh
./pugixml/bootstrap.sh
./boost/bootstrap.sh
./libarchive/bootstrap.sh
./spdlog/bootstrap.sh
./AppAuth/bootstrap.sh