# 3rd Party Dependencies

## Approach

Nimble Commander is built with the goal of being as hermetic as reasonably possible.  
This means:
  * All dependencies are linked statically into a single executable binary.
  * Symbol visibility is hidden in both 3rd-party libraries and Nimble Commander itself.
  * Both 3rd-party libraries and Nimble Commander are built with link-time optimization.

Dependencies are manually bootstrapped, and the precompiled versions are stored directly within the Nimble Commander repository.

The following flags or their equivalents (e.g., when the 3rd-party library uses CMake or Xcode projects) should be uniformly applied:

| Flag                       | Comments
| -------------------------- | -------------------------------------------------------
| -std=c++2b                 | Enable C++23
| -arch x86_64               | Build for Intel architecture 
| -arch arm64                | Build for Apple Silicon architecture
| -mmacosx-version-min=10.15 | Minimum supported target version of macOS is 10.15
| -DNDEBUG                   | Disable debug assertions
| -fvisibility=hidden        | Set symbol visibility to hidden
| -flto                      | Enable link-time optimization
| -Os                        | Optimization level 2 plus reduced code size

## Rebuilding

`3rd_Party/bootstrap.sh` rebuilds all dependencies in topological order. Each dependency directory contains its own `bootstrap.sh` script, which downloads, builds, and installs the library. Only headers and compiled artifacts are retained afterwards.  
NB! Ensure the correct Xcode version is selected before running the bootstrap script.  
Verify the Xcode version with `xcode-select -p`.

## Libraries

| Library         | Version    | Source Code
| --------------- | ---------- | -----------------------------------------
| appauth         | 1.7.5      | https://github.com/openid/AppAuth-iOS.git
| boost           | 1.85.0     | https://boostorg.jfrog.io/artifactory/main/release/1.85.0/source/boost_1_85_0.tar.gz
| bz2             | 1.0.8      | https://sourceware.org/git/bzip2.git
| Catch2          | v2.13.3    | https://github.com/catchorg/Catch2
| curl            | 8.7.1      | https://github.com/curl/curl.git
| fmt             | 10.2.1     | https://github.com/fmtlib/fmt.git
| frozen          | 1.1.1      | https://github.com/serge-sans-paille/frozen
| gtest           | 1.14.0     | https://github.com/google/googletest.git
| letsmove        | 1.25       | https://github.com/potionfactory/LetsMove.git
| lexilla         | 5.3.2      | https://github.com/ScintillaOrg/lexilla.git
| libarchive      | 3.7.4      | https://github.com/libarchive/libarchive.git
| libcxx          | 18.x       | https://github.com/llvm/llvm-project.git
| libssh2         | 1.11.0     | https://github.com/libssh2/libssh2.git
| lz4             | 1.9.4      | https://github.com/lz4/lz4.git
| lzma(xz)        | 5.4.6      | https://github.com/tukaani-project/xz.git
| lzo             | 2.10       | http://www.oberhumer.com/opensource/lzo/download/lzo-2.10.tar.gz
| nlohmann        | 3.11.3     | https://github.com/nlohmann/json.git
| openssl         | 1.1.1v     | https://github.com/openssl/openssl.git
| pstld           | head       | https://github.com/mikekazakov/pstld
| pugixml         | 1.14       | https://github.com/zeux/pugixml.git
| rapidjson       | head       | https://github.com/Tencent/rapidjson
| re2             | 2023-03-01 | https://github.com/google/re2.git
| sparkle         | 2.6.1      | https://github.com/sparkle-project/Sparkle.git
| spdlog          | 1.14.1     | https://github.com/gabime/spdlog.git
| unordered_dense | 4.4.0      | https://github.com/martinus/unordered_dense.git
| zlib            | 1.3.1      | https://zlib.net/zlib-1.3.1.tar.gz
| zstd            | 1.5.6      | https://github.com/facebook/zstd.git
