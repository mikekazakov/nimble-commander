//
//  VFSArchiveUnRARListing.h
//  Files
//
//  Created by Michael G. Kazakov on 04.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include <vector>
#include "VFSListing.h"
#include "VFSArchiveUnRARInternals.h"
#include "VFSArchiveUnRARHost.h"

class VFSArchiveUnRARListing : public VFSListing
{
public:
    VFSArchiveUnRARListing(const VFSArchiveUnRARDirectory &_dir,
                           const char *_path,
                           int _flags,
                           shared_ptr<VFSHost> _host);
    
    
    virtual VFSListingItem& At(size_t _position) override { return m_Items[_position];};
    virtual const VFSListingItem& At(size_t _position) const override { return m_Items[_position];};
    virtual int Count() const override { return (int)m_Items.size();}
    
private:
    vector<VFSGenericListingItem> m_Items;
};

