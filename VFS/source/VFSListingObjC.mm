#include "../include/VFS/VFSListing.h"

NSString* VFSListing::FilenameNS(unsigned _ind) const
{
    return (__bridge NSString*)FilenameCF(_ind);
}

NSString* VFSListing::DisplayFilenameNS(unsigned _ind) const
{
    return (__bridge NSString*)DisplayFilenameCF(_ind);
}

NSString* VFSListingItem::NSName() const
{
    return L->FilenameNS(I);
}

NSString* VFSListingItem::NSDisplayName() const
{
    return L->DisplayFilenameNS(I);
}
