// Copyright (C) 2019-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../Tests.h"
#include <VFS/NetSFTP.h>
#include <fstream>

static bool Save(const std::string &_filepath, const std::string &_content);

static const std::string_view g_OpenKey = "-----BEGIN RSA PRIVATE KEY-----\n"
                                          "MIIEowIBAAKCAQEA5hkdNyAy8bqnj+NLpEDjCwfuJlaslnj5SlHri+0lBqQUpxLw\n"
                                          "d6YY3HOxjmUrqZrMf/i0Foj5+vueEe8xQ+TA41WMEdDD8RXSHMcmfGrXmaLetQ3P\n"
                                          "ePUcUyux8L9TwMdgNOrFE6r/n14nOacQ1UJCOYPdNwao2dzGj4AAEMOKdYmOXhC6\n"
                                          "0ry7StA4O4uY+INlHezuqEoLr0luqCaQrK77LQf/I71YI8A3Y4pG09SNHxYtrUex\n"
                                          "3MMuNjGKbf/igzTYUR6IUrtsO1pgO/QSLFZdHujx2gpEEu3hGLXRHATqLK1fLBB9\n"
                                          "+M/QvVvuLDuekaH9e1mDr7DRjkn1GS28ogxY0wIDAQABAoIBAFcN62K+2Odh4iFr\n"
                                          "MmQbdIro3i49HqDzdgWrRr2y5A5GJ9YqMTZjbgaB8wxXtJQ/j91e3+uiuUk+x0gr\n"
                                          "wezY8C1SYWMgI/HjepIOur3ZwmZLG41Og09VFPlWj8Tw7iQCiqCariNJz9qgyaBj\n"
                                          "V9gHcHzIKfq2l02N3MXP/LZa9NiQkdbFqcmi5ZVkptYBHtccbNnsAXCFhfCDoyKx\n"
                                          "ZbKHxSzxdQB20nuo5aXDbIpSFzX7uR5uAAibIpkO/j6c2SuV9fXjvWeKtgsw+jMf\n"
                                          "Ym+1WAMVb3ZiBJUv8dp7qaNxNGdVnFalyFlVefulWakYOrcbjd6y1FlfXm6fZcP6\n"
                                          "PTQHBaECgYEA9SSmjQfGIHCxAMxVt/MX073D4pN8GLAJJ+k/kP5nRd0c+eTsP2aP\n"
                                          "bOemc9YeiUZM3Rx/4AkiyjyrRNPtih64v32Izbld1qy2GTHHMB4iGWMpk2B4bGQ7\n"
                                          "b95ifUp90/6eB/2/PkMPtAePjzufOcPRyXmUamgmEY4gk6jJN12H6IMCgYEA8Enj\n"
                                          "Qr+xKLBy/Q1P/d2q4QwmaSHLFaLMUDhoZMp7dV/fmhtvnJnDQ4YB4u9aa2G7vz6N\n"
                                          "v7tKIDjmyKA5ZTi6PEhuov52pX05ShBX67fps+gLyVuPr1zL3xvaIqF1KiRqonST\n"
                                          "UQCoXLYitn0JrAUepnFfTrJ6OORmf6Um0YsivXECgYA5BFREmxlG9E8G+3+4cC8L\n"
                                          "jaig62LCrzcB9GtXgwRsKHiT2t3kBSu4zcxWRugFT7eS+gz4A8f2t9OyB4TJSkn4\n"
                                          "J++IweOEidk01PIaS/fsZbcG0zpPI6T7aQMJVykbBK6m9yrjBWACpHuMefaXzebe\n"
                                          "cIvHj//Ct4b2MRzT5so0lwKBgQCaTni41q0H+jf9tVzXJFCl8M2B2ge2vzMBmRfB\n"
                                          "Eh6yQ30uU8wa/stcQ2RWvWqNZtfQenVA2R9DDgd2cx4omINQTxttZIgAwifWHiS3\n"
                                          "5QUZWTyodDoTXT426oXsk07QX05zQPWRoSB9WSF1m1pos2j5bfjMauT+P/5qnj4N\n"
                                          "dpI6oQKBgFe/9Ipd4paRTCwt6hHAn9p7vi5TrUqGquAQXDlZD3BA0RSVeFrdHz3c\n"
                                          "kvt8U2tTzw4BWLMdCdRwk5swOQs99yiZs0Pbi8kZx6NOE6pc1x+u+2rAhpFWiuuD\n"
                                          "Ki8o7xK/HPRWVYOAenGWRQs/r3HkJ7iI7pVYWw18geawpP6sBGBP\n"
                                          "-----END RSA PRIVATE KEY-----";

static const std::string_view g_EncryptedKey = "-----BEGIN RSA PRIVATE KEY-----\n"
                                               "Proc-Type: 4,ENCRYPTED\n"
                                               "DEK-Info: AES-128-CBC,6397094C8D46B32E2155F4DB67E6F862\n"
                                               "\n"
                                               "wMLA5AIdg0mWLKLD3rIG7VU6QP4+YrANRULt5CmBPlzPUBzLJg+qwb37mmqeGQS2\n"
                                               "XBR2uoNEjBiHzHfdOmsdY0nT8vtkmQiHudze1DxMIsFniBR82bmTPa3ohyvQrSsZ\n"
                                               "D5LHMunHngat60pWAkSiFZOaycUu2qTXsdbXOzMbCLnOYule/WYrcHrKqEvmc0EN\n"
                                               "spReJPSaez++puXimLUXYB6F0iLDwNsTZLXPFP1eHV6vitfUEZ5cCV+hCqYbm8WS\n"
                                               "TvZ26+RHhIC/JffM6V8i2DF6nBhMs+sTFqehDrt6d4V578ICiP6V9MwaqIJNS2Ot\n"
                                               "XO26e8ST/7TMTxWNbS2M/FG/0gmC9Ifpu2+zItcJg7oMtN14phPBtqn8gJ+Rjq0X\n"
                                               "ULp+xIMdua1qPR1GWm+/71BCym3NkwIhQEC70DaMsoXXQMMulHdOemdeUCS18hcF\n"
                                               "roXUHKI4ozeLpLpiZsjAghjMPVAmYtkcqPRQa+BPq8yxuaHUbuuhxxGLjrkUDEnB\n"
                                               "pOgM2+1vBY8PgdFjca7yBP4qxudaKr16piGXDkNwKD6TUNmJahF30SoObbCBWJo6\n"
                                               "SyO1PXvJfzeQxLU8DnVJFbUJWqa+X+00T3w5+bG17rVZeO7hCamZHkKD73qKuKH4\n"
                                               "ICmr83PY7HkYskKFruB6SI2XdzvxC2jG9QiYr4+boLs7z/QYJ9KBZSK6OJurTPOL\n"
                                               "sZDrPMIx0Xh/wsLIvOqaIsNUh/HWv7jyvI+YesJ270ihDMzDSZW13tiXC8Kk35ln\n"
                                               "72r/q3TmxLnA8iUOddoq4l6ZTNY+fq9q2PF2gmm6Ks9bIqKjVwjhz/QESx7o13fr\n"
                                               "50ANMHxa/I6YfleDQ7eUf3JIrj/AFUInRQgKWp6oA4kuGsQloJFCke7+83Lwq4wi\n"
                                               "u/5B+Y8ruthemlLFuroQvVZvlaQx4ykxtpmhFg2+5H/JokZx/HUqbKRXTLfXiAq4\n"
                                               "ZIQv5LoKeQLdwlUYIkhT5rnJwsKlJnPA6Mf2B5r+MFssnvCwjX84/OMBTqYCFxrc\n"
                                               "DWQRCBXB7bEgmjWbasH8s484APwn3l56rKzXhHY0+azTz56ZizzxOOKSashbmosw\n"
                                               "QIDfuerHP3OQ5NGOxM62eesFa6AE4Z4bfYX3q6TAJqvNZv96j0dY/1FpkgLnycTz\n"
                                               "KU9aAvgl1e7XBdQQqIcVBf92GfMphYpbBwhUUei6pd+I6jA0ct7N6eMh4OPhKHT0\n"
                                               "8d6MpPi3+zNf+woXr7AsYalJFya+oXGzIwdf0aVeAdYdQKFei175EdoMWKggDDuz\n"
                                               "A0muLtKdq78X8K2LOPPOHWG1RyMn97jYQZVZ8Y1jGM4K+IXYsGI1AjCQzPYUSX7v\n"
                                               "lnUFqbHHVOmVqWeNYmxeiAOqCCaEWxJbwN0WcUyNr0Kdh6WL/lOOUTIP8TqLFymA\n"
                                               "4qDpBmdZRTqMM0negZlliM9KrWFySBM/gIvs5A93N1kYyGgMmtrwWrTduxOmZGZP\n"
                                               "eCA3C8GqFRGBfRSAevCY8PaT76wJwg7b5JoP1LveF4zlIf4NLZX0InhDiEIFz/sP\n"
                                               "pfbj7vn7uCuauv45yvAKUbNJJbjMNA4h1rfDaiEuzkxirA9h1luywG17WEVHDAWP\n"
                                               "-----END RSA PRIVATE KEY-----";

static const std::string_view g_OpenSSH1024Encrypted =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABA4SE4XGV\n"
    "fYd/C3IWVWaP6MAAAAEAAAAAEAAACXAAAAB3NzaC1yc2EAAAADAQABAAAAgQDsnvT2WhPF\n"
    "0l/Yv1NUeJPNVaDSPtthUrcPcCeUuL1JwojzrA8M19GzinzbgtgjDOZkJYT/7hvWy8yBLu\n"
    "/hVAnUIVGaHsT5jWA80aUGhPQ3fsC1FdLi4XG1BHP9228WJSmgPSeFjQmVDjIVkw89SmEP\n"
    "01jxQPGlcGycO7NgbXSakwAAAiA5Prue4wKi8/KU2+rs0pTPINRdMCapWahs8rV3h45nTh\n"
    "1Wrx+10L7MBNih/IOtFeuXyuZ1lVNVLw15OBNqhPCk7IpckJhXx499zfn9jw7rIoJq0njN\n"
    "fK1ZDq+WYL7v5Iuu9RgHxqy0NjVyTnsYlQGgcTu5uCyJVj/E0VTKlts+n0OzQyWojR41km\n"
    "NZUDZKncEGU2pz1DIWtb3P7IXQ5KfycLagb2GgNDYU7zf9MYCTvRHGtdqP5eaE972yaDIM\n"
    "ZN6VXV2NoimR4MZ9X+FQNjuDh/rLX+V0YPds4Al4mQnPbxPrK4CvBquCXtASHDUoXJX3dy\n"
    "TuhxK32aIzOo+lKT6leGBkmwXZpe2s4IcIjMkAE7LtUn0xbqRyffH5wMi6objKxJykhr6z\n"
    "LymftCXPOKlMRPKR2tY0CLyYYleMxVnuOLq/dwA0QUIJPkMVAGUpJGYtNFrzFGAvuHjADV\n"
    "5FtAonLGSNFxl1GsEqk/Fxyi/pM3x9R6u8num5LDKr5Sps3zIYls1zAN4Jss+sjaPLfa1s\n"
    "wPWtvu1+Y9jvbQ10CVk/AjQ/V7DtaS3PU1PE9vP/JozeSOyCCBJxENurQLGZfhd9XvR3Un\n"
    "ddYk4BABCBI/8l6qGAvmSnvGanyDG4kIEFasRGl6bIrAQE53MQHvYl5QCyWf47gqj8AWKW\n"
    "srVkE1iiKuX2O4OgzhOsUv8AUuIDuy1bCal7xLEzkgY4wEqTbr+Y\n"
    "-----END OPENSSH PRIVATE KEY-----";

static const std::string_view g_OpenSSH2048Encrypted =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "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\n"
    "-----END OPENSSH PRIVATE KEY-----";

static const std::string_view g_OpenSSH4096Encrypted =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "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\n"
    "-----END OPENSSH PRIVATE KEY-----";

static const std::string_view g_OpenSSH1024DSAEncrypted =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABCK1OiiuI\n"
    "ELnirUensI9M0qAAAAEAAAAAEAAAGxAAAAB3NzaC1kc3MAAACBAJo1x1bF9ddo+CZ0H1om\n"
    "2VknSpfrJL7B55HWaf9ET2fm5hj39BZ8CCtW1HvxRB9G7SCDmI02mAjXNnz2vhHVnk/OYo\n"
    "rTgOBOmdkqPkI9NCT7pnM/O7g1GP2SLitznaCQZsoDsOsXcxetphEuOfnSoJJl4h4VZ2n3\n"
    "beKFmkMWTWHLAAAAFQCtkx7o9yFbUjC3VTyIBtqOO9Zn9wAAAIAvhyTe8kaxJUFK2f6ic5\n"
    "RVLdQ7ZflMegJLoGqS1Jhg/SGrPxgDscb9p44zyFIdFP3sMPBkFzPcZ5vfmBqeAsqxSyig\n"
    "21CUlHC0tn6OAY4Ey8lgpcuGrIlvkZ+kvrKDLhnUAJuAMxVOKUvB7+skxxgxuFZJYxtkg8\n"
    "87EnkomGR9IgAAAIBxm1qRJGOEZtBlCQ5xzhAW2J43bKk0Gmp4a03wiyv/CT21dhHqodwO\n"
    "r7Hfoa2Zqamj+NIrK7m4oD8htFFoED1ya8JVgUzrNr1wALiJ+S5zh2q09xPyExXIHP+yMn\n"
    "tgdelXN8yjdVhXY5KvSL9PUGFK9shkrikIqNkHG7A0wNiMGwAAAgApYrtlXsg7SxauDT7D\n"
    "U2Kt9FyebW8L1TaJLIvGrgcD2BtkFVJRtM6Hx00+zdnRhVZNeEpdLiovlS1IHyprfwrNPX\n"
    "UQaLjpvsWYHabxyixTVK3NGiaMmMysotTVDKE5ieoHCFDav8LTH+1SgvyXyj14M4gbGBLq\n"
    "2oBXpHfl9vmIRNE+t4VFiYhPwguMX6PZ+7zULDZxzsB4GP5ZCith/kD/sfb7keOj6c0fs8\n"
    "rf5vvoKS8+FsxQlVBYUSHAjtuxQdUFdfYA/e2sDqMYHtEc6qeeZkvbL8HOJ4/+kuIC6fko\n"
    "WFYoQ/d87sEGaZ119D1mgIdrwi0LRTyQ0+69DxgdNjmx8t9aFLYbFKCO48f4oUMsqro995\n"
    "6nghE//b1ApcZ+3vMHpXbimgXuZmt8NiyqTtzjVVkbP37eT9XQ6/wq9iWCI3gvRJby56dZ\n"
    "j3+0Aq/jFJNRa2FprMU4z5wN6vSkAX6jldd/LT7VyEH/pMVjpm2A4YkXBzigCUqmaOE3sr\n"
    "yiNZvcFP9jPfYBOwdx5oL6xw3+/cduN3HOCeL+OCTOZ3LStYj4+KoNzE2QsF+pc+xpWGTY\n"
    "L/8ZPoKvBehD1BDvzw5pUJT0l0HnOx+ll95MFS7Pwvm95JLTf2+LNwskouzdHfyd3d9HcQ\n"
    "ioLCzx+ikB6TpNTQ3TMn7pB/+EpwQ3cxqOww==\n"
    "-----END OPENSSH PRIVATE KEY-----";

static const std::string_view g_OpenSSHECDSAEncrypted =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABCSLpstY+\n"
    "Doe8kwLegixEVMAAAAEAAAAAEAAABoAAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlz\n"
    "dHAyNTYAAABBBJbp94QttboS4Egf03IcBxc/3Q/AcA/1zla9JoSARNEupdIRGa7GO4CIOs\n"
    "ZInWJPmSYvH5KhUtgYvvaW6i5an7cAAADA6qBOlL1VX7sdjwqbsv0IbMPPrAzeLjkwSl5V\n"
    "IqXCvJJeRaDKrB7dYi3x3s0XGKs4OYvbyscfju+DtdTJJNds6gPwdGFhnbtNCDqoEEQ3dL\n"
    "03heEX6m+VMvadnc+lU1/N1GuqbvDLq73MmerV5P5jFa2cBS8NvQqdyxZaLS4U5IyE2S78\n"
    "Oy9PaczJM8fXjxbOJRhJhYTn/FXa4cCTLkIIU757dSgIxvwPgF3PHKRWO0k8DAwCUoQ3VU\n"
    "BjSL5BHpAY\n"
    "-----END OPENSSH PRIVATE KEY-----";

static const std::string_view g_OpenSSHED25519Encrypted =
    "-----BEGIN OPENSSH PRIVATE KEY-----\n"
    "b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABCcSyGLZI\n"
    "LnBpYVPrV3NSNvAAAAEAAAAAEAAAAzAAAAC3NzaC1lZDI1NTE5AAAAILZ5P3lQGLGj6rLw\n"
    "8QFzaeIJbbLcDP7d++3i1vGmsMc1AAAAoMs1H0kSwXkCIdIq9knOz7R2Ph5SkU3x71Djl5\n"
    "45EabaIASgWZlh0HJsumkZtTad7qufk6O5bwoTu7fBtOrQMSA5mqQ0X7KLGjjJaAvUsZbn\n"
    "Zo2p/Oel9MfXk/y8KBatCs6SDCp36mYJeVAP7zu1YP/qnZwcKhjYiomwstsyjxk1SS06lD\n"
    "9D25BkEY8ZF4OVl3PtjJgv9/DM5mOPnVJleF8=\n"
    "-----END OPENSSH PRIVATE KEY-----";

#define PREFIX "nc::vfs::sftp::KeyValidator "
using nc::vfs::sftp::KeyValidator;

TEST_CASE(PREFIX "refuses to validate an unexising key")
{
    CHECK(KeyValidator{"/some/path/", ""}.Validate() == false);
    CHECK(KeyValidator{"/some/path/", "1231321232"}.Validate() == false);
    CHECK(KeyValidator{"/some/path/", "some jibberish"}.Validate() == false);
}

TEST_CASE(PREFIX "validates an existing open RSA key")
{
    const TestDir test_dir;
    const auto path = test_dir.directory / "key";
    Save(path, std::string{g_OpenKey});
    CHECK(KeyValidator{path, ""}.Validate());
    CHECK(KeyValidator{path, "1231321232"}.Validate());
    CHECK(KeyValidator{path, "some jibberish"}.Validate());
}

TEST_CASE(PREFIX "validates an existing encrypted RSA-AES-128-CBC key")
{
    const TestDir test_dir;
    const auto path = test_dir.directory / "key";
    Save(path, std::string{g_EncryptedKey});
    CHECK(KeyValidator{path, ""}.Validate() == false);
    CHECK(KeyValidator{path, "1231321232"}.Validate() == false);
    CHECK(KeyValidator{path, "some jibberish"}.Validate() == false);
    CHECK(KeyValidator{path, "qwerty"}.Validate() == true);
}

TEST_CASE(PREFIX "validates an existing encrypted OpenSSH-1024 key")
{
    const TestDir test_dir;
    const auto path = test_dir.directory / "key";
    Save(path, std::string{g_OpenSSH1024Encrypted});
    CHECK(KeyValidator{path, ""}.Validate() == false);
    CHECK(KeyValidator{path, "1231321232"}.Validate() == false);
    CHECK(KeyValidator{path, "some jibberish"}.Validate() == false);
    CHECK(KeyValidator{path, "qwerty"}.Validate() == true);
}

TEST_CASE(PREFIX "validates an existing encrypted OpenSSH-2048 key")
{
    const TestDir test_dir;
    const auto path = test_dir.directory / "key";
    Save(path, std::string{g_OpenSSH2048Encrypted});
    CHECK(KeyValidator{path, ""}.Validate() == false);
    CHECK(KeyValidator{path, "1231321232"}.Validate() == false);
    CHECK(KeyValidator{path, "some jibberish"}.Validate() == false);
    CHECK(KeyValidator{path, "qwerty"}.Validate() == true);
}

TEST_CASE(PREFIX "validates an existing encrypted OpenSSH-4096 key")
{
    const TestDir test_dir;
    const auto path = test_dir.directory / "key";
    Save(path, std::string{g_OpenSSH4096Encrypted});
    CHECK(KeyValidator{path, ""}.Validate() == false);
    CHECK(KeyValidator{path, "1231321232"}.Validate() == false);
    CHECK(KeyValidator{path, "some jibberish"}.Validate() == false);
    CHECK(KeyValidator{path, "qwerty"}.Validate() == true);
}

TEST_CASE(PREFIX "validates an existing encrypted OpenSSH-1024 DSA key")
{
    const TestDir test_dir;
    const auto path = test_dir.directory / "key";
    Save(path, std::string{g_OpenSSH1024DSAEncrypted});
    CHECK(KeyValidator{path, ""}.Validate() == false);
    CHECK(KeyValidator{path, "1231321232"}.Validate() == false);
    CHECK(KeyValidator{path, "some jibberish"}.Validate() == false);
    CHECK(KeyValidator{path, "qwerty"}.Validate() == true);
}

TEST_CASE(PREFIX "validates an existing encrypted OpenSSH-ECDSA key")
{
    const TestDir test_dir;
    const auto path = test_dir.directory / "key";
    Save(path, std::string{g_OpenSSHECDSAEncrypted});
    CHECK(KeyValidator{path, ""}.Validate() == false);
    CHECK(KeyValidator{path, "1231321232"}.Validate() == false);
    CHECK(KeyValidator{path, "some jibberish"}.Validate() == false);
    CHECK(KeyValidator{path, "qwerty"}.Validate() == true);
}

TEST_CASE(PREFIX "validates an existing encrypted OpenSSH-ED25519 key")
{
    const TestDir test_dir;
    const auto path = test_dir.directory / "key";
    Save(path, std::string{g_OpenSSHED25519Encrypted});
    CHECK(KeyValidator{path, ""}.Validate() == false);
    CHECK(KeyValidator{path, "1231321232"}.Validate() == false);
    CHECK(KeyValidator{path, "some jibberish"}.Validate() == false);
    CHECK(KeyValidator{path, "qwerty"}.Validate() == true);
}

static bool Save(const std::string &_filepath, const std::string &_content)
{
    std::ofstream out(_filepath, std::ios::out | std::ios::binary);
    if( !out )
        return false;
    out << _content;
    out.close();
    return true;
}
