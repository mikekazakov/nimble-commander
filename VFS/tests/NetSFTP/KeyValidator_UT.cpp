// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../Tests.h"
#include <VFS/NetSFTP.h>

static bool Save(const std::string &_filepath, const std::string &_content);

static const std::string_view g_OpenKey = 
"-----BEGIN RSA PRIVATE KEY-----\n"
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

static const std::string_view g_EncryptedKey = 
"-----BEGIN RSA PRIVATE KEY-----\n"
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

#define PREFIX "nc::vfs::sftp::KeyValidator "
using nc::vfs::sftp::KeyValidator;

TEST_CASE(PREFIX" refuses to validate an unexising key")
{
    CHECK( KeyValidator{"/some/path/", ""}.Validate() == false );
    CHECK( KeyValidator{"/some/path/", "1231321232"}.Validate() == false );
    CHECK( KeyValidator{"/some/path/", "some jibberish"}.Validate() == false );
}

TEST_CASE(PREFIX" validates an existing open key")
{
    TestDir test_dir;
    const auto path = test_dir.directory + "key"; 
    Save(path, std::string{g_OpenKey});
    CHECK( KeyValidator{path, ""}.Validate() );
    CHECK( KeyValidator{path, "1231321232"}.Validate() );
    CHECK( KeyValidator{path, "some jibberish"}.Validate() );
}

TEST_CASE(PREFIX" validates an existing encrypted key")
{
    TestDir test_dir;
    const auto path = test_dir.directory + "key"; 
    Save(path, std::string{g_EncryptedKey});
    CHECK( KeyValidator{path, ""}.Validate() == false );
    CHECK( KeyValidator{path, "1231321232"}.Validate() == false );
    CHECK( KeyValidator{path, "some jibberish"}.Validate() == false );
    CHECK( KeyValidator{path, "qwerty"}.Validate() == true );
}

static bool Save(const std::string &_filepath, const std::string &_content)
{
    std::ofstream out( _filepath, std::ios::out | std::ios::binary );
    if( !out )
        return false;        
    out << _content;    
    out.close();
    return true;
}
