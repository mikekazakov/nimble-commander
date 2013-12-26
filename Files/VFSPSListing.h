//
//  VFSPSListing.h
//  Files
//
//  Created by Michael G. Kazakov on 26.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "VFSListing.h"
#import "VFSPSHost.h"
#import "VFSPSInternal.h"

struct VFSPSListingItem : VFSListingItem
{
    VFSPSHost::Snapshot *data;
    unsigned             index;
    CFStringRef         cf_name;

    virtual const char     *Name()      const override {
        return data->plain_filenames[index].c_str();
    }
    
    virtual CFStringRef     CFName()    const override {
        return cf_name;
    }
    
    virtual size_t          NameLen()   const override {
        return data->plain_filenames[index].length();
    }
    
    
    
    inline void Destroy()
    {
        if(cf_name != 0)
            CFRelease(cf_name);
    }
};

class VFSPSListing : public VFSListing
{
public:

    VFSPSListing(const char* _relative_path,
                 shared_ptr<VFSPSHost> _host,
                 shared_ptr<VFSPSHost::Snapshot> _snapshot
                 );
    virtual ~VFSPSListing();

    
    virtual VFSListingItem& At(size_t _position) override;
    virtual const VFSListingItem& At(size_t _position) const override;
    virtual int Count() const override;
    

private:
    shared_ptr<VFSPSHost::Snapshot> m_Snapshot;
    vector<VFSPSListingItem>        m_Items;
};
