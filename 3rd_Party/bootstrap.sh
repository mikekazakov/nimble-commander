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
./ctrail/bootstrap.sh
./googletest/bootstrap.sh
./unrar/bootstrap.sh
./robin_hood/bootstrap.sh
./AppAuth/bootstrap.sh
./Sparkle/bootstrap.sh
./LetsMove/bootstrap.sh
./AquaticPrime/bootstrap.sh
./frozen/bootstrap.sh
