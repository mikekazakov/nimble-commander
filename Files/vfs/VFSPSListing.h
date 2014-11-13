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
    
    virtual size_t          NameLen()   const override {
        return data->plain_filenames[index].length();
    }
    
    virtual CFStringRef     CFName()    const override {
        return cf_name;
    }
    
    virtual uint64_t        Size()      const override {
        return data->files[index].size();
    }
    
    virtual time_t          ATime()     const override { return data->taken_time; }
    virtual time_t          MTime()     const override { return data->taken_time; }
    virtual time_t          CTime()     const override { return data->taken_time; }
    virtual time_t          BTime()     const override { return data->taken_time; }
    virtual mode_t          UnixMode()  const override { return S_IFREG | S_IRUSR | S_IRGRP; }
    
    
    virtual bool            HasExtension() const { return true; }
//    virtual unsigned short  ExtensionOffset() const { return 0; }
    virtual const char*     Extension() const { return "txt"; }
    
    
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
