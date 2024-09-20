// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Hash.h"
#include "UnitTests_main.h"

using nc::base::Hash;

#define PREFIX "Hash "

TEST_CASE(PREFIX "check the hash results")
{
    const std::string d = "6Bwbu8HbVqF*GPNL$BR[Jh4Nk)$!afU#w6[erC4yYX2&$]"
                          "VUzGjsaQ6M#%ZdJk${VbsWw_!F^NMnfDCC5A=5bPNf(#*"
                          "HKYmu8NJd4qdAM[+a)4--J*mj#x7SriKU=sH6";

    CHECK(Hash::Hex(Hash(Hash::SHA1_160).Feed(d.c_str(), d.size()).Final()) ==
          "d73c1e4c9531646c26605f672bfe1c74b4a40bd7");
    CHECK(Hash::Hex(Hash(Hash::SHA2_224).Feed(d.c_str(), d.size()).Final()) ==
          "c5023cbfc38ddaa4c599cde471a9f1a6a7c8ff6192c0d560e4a7b188");
    CHECK(Hash::Hex(Hash(Hash::SHA2_256).Feed(d.c_str(), d.size()).Final()) ==
          "4a84ea5c9de9d3acf289151bbd8a2db3b8b3ec0f695bba23d7dc62601c02725f");
    CHECK(Hash::Hex(Hash(Hash::SHA2_384).Feed(d.c_str(), d.size()).Final()) ==
          "cfe5069434e541cf8fdc6076ef1850875d6407c0043d4bb687579cd52d7f13c489095a"
          "120dddd4d279aaefa941f3d34f");
    CHECK(Hash::Hex(Hash(Hash::SHA2_512).Feed(d.c_str(), d.size()).Final()) ==
          "5e648bcc3fc9ebd87128a9272167af99a12df927d2dbc1547674827a7a91ccafe61a4d"
          "fa92e209b41b98dbe2bd204f049bd3730496b4"
          "680aaf6d362a73f9c677");
    CHECK(Hash::Hex(Hash(Hash::MD2).Feed(d.c_str(), d.size()).Final()) == "754b67a193402945bc87a641cecddef6");
    CHECK(Hash::Hex(Hash(Hash::MD4).Feed(d.c_str(), d.size()).Final()) == "99fa84d915d2917a174c26fed2843441");
    CHECK(Hash::Hex(Hash(Hash::MD5).Feed(d.c_str(), d.size()).Final()) == "189b20088062f608cc1c9ce6002e10e0");
    CHECK(Hash::Hex(Hash(Hash::Adler32).Feed(d.c_str(), d.size()).Final()) == "e3d9270a");
    CHECK(Hash::Hex(Hash(Hash::CRC32).Feed(d.c_str(), d.size()).Final()) == "d3ec3da8");
}
