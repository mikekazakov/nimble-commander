// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Listing.h"

NSString* VFSListing::FilenameNS(unsigned _ind) const
{
    return (__bridge NSString*)FilenameCF(_ind);
}

NSString* VFSListing::DisplayFilenameNS(unsigned _ind) const
{
    return (__bridge NSString*)DisplayFilenameCF(_ind);
}

NSString* VFSListingItem::FilenameNS() const
{
    return L->FilenameNS(I);
}

NSString* VFSListingItem::DisplayNameNS() const
{
    return L->DisplayFilenameNS(I);
}
