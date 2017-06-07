#include "Operations.h"
#include <VFS/Native.h>

int VeryImportantFunction()
{
    cout << (void*)VFSNativeHost::Tag << endl;
    return 42;
}


AbraCadabra::AbraCadabra()
{
    cout << (void*)VFSNativeHost::Tag << endl;
}


int AbraCadabra::Process(int a)
{
    return a * 2;
}
