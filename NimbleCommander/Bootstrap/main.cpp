// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
extern "C" int NSApplicationMain(int argc, const char *argv[]);

bad_optional_access::~bad_optional_access() noexcept = default;

int main(int argc, char *argv[])
{
    return NSApplicationMain(argc, (const char **)argv);
}
