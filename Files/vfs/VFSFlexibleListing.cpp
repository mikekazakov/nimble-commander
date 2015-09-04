//
//  VFSFlexibleListing.cpp
//  Files
//
//  Created by Michael G. Kazakov on 03/09/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "VFSFlexibleListing.h"

static bool BasicDirectoryCheck(const string& _str)
{
    if( _str.empty() )
        return false;
    if( _str.back() != '/' )
        return false;
    return true;
}

static void Validate(const VFSFlexibleListingInput& _source)
{
    if( _source.hosts.mode() == variable_container<>::type::sparse )
        throw logic_error("VFSFlexibleListingInput validation failed: hosts can't be sparse");
    
    for( auto i = 0u, e = _source.hosts.size(); i != e; ++i )
        if( _source.hosts[i] == nullptr )
            throw logic_error("VFSFlexibleListingInput validation failed: host can't be nullptr");
    
    if( _source.directories.mode() == variable_container<>::type::sparse )
        throw logic_error("VFSFlexibleListingInput validation failed: directories can't be sparse");

    for( auto i = 0u, e = _source.directories.size(); i != e; ++i )
        if( !BasicDirectoryCheck( _source.directories[i] ) )
            throw logic_error("VFSFlexibleListingInput validation failed: invalid directory");
    
    for( auto &s: _source.filenames )
        if( s.empty() )
            throw logic_error("VFSFlexibleListingInput validation failed: filename can't be empty");
    
    if( _source.display_filenames.mode() == variable_container<>::type::common )
        throw logic_error("VFSFlexibleListingInput validation failed: dispay_filenames can't be common");

    if( _source.sizes.mode() == variable_container<>::type::common )
        throw logic_error("VFSFlexibleListingInput validation failed: sizes can't be common");

    if( _source.inodes.mode() == variable_container<>::type::common )
        throw logic_error("VFSFlexibleListingInput validation failed: inodes can't be common");

    if( _source.symlinks.mode() == variable_container<>::type::common )
        throw logic_error("VFSFlexibleListingInput validation failed: symlinks can't be common");
    
    unsigned items_no = (unsigned)_source.filenames.size();
    if(_source.hosts.mode() == variable_container<>::type::dense &&
       _source.hosts.size() != items_no )
        throw logic_error("VFSFlexibleListingInput validation failed: hosts amount is inconsistent");
    
    if(_source.directories.mode() == variable_container<>::type::dense &&
       _source.directories.size() != items_no)
        throw logic_error("VFSFlexibleListingInput validation failed: directories amount is inconsistent");
}

shared_ptr<VFSFlexibleListing> VFSFlexibleListing::Build(VFSFlexibleListingInput &&_input)
{
    Validate( _input ); // will throw an exception on error

    auto l = Alloc();
    l->m_Filenames = move(_input.filenames);
    l->BuildFilenames();

    
    
    return l;
}

shared_ptr<VFSFlexibleListing> VFSFlexibleListing::Alloc()
{
    struct make_shared_enabler: public VFSFlexibleListing {};
    return make_shared<make_shared_enabler>();
}

VFSFlexibleListing::VFSFlexibleListing()
{
}

unsigned VFSFlexibleListing::Count() const
{
    return (unsigned)m_Filenames.size();
}

void VFSFlexibleListing::BuildFilenames()
{
    size_t i = 0, e = m_Filenames.size();
    m_ItemCount = (unsigned)e;
    
    m_FilenamesCF.resize( e );
    m_ExtensionOffsets.resize( e );
    for(; i != e; ++i ) {
        auto &current = m_Filenames[i];
        
        // build Cocoa strings for filenames.
        // if filename is badly broken and UTF8 is invalid - treat it like MacRoman encoding
        CFString s( current );
        if( !s )
            s = CFString( current, kCFStringEncodingMacRoman );
        m_FilenamesCF[i] = move(s);
        
        // parse extension if any
        // here we skip possible cases like
        // filename. and .filename
        // in such cases we think there's no extension at all
        uint16_t offset = 0;
        auto dot_it = current.find_last_of('.');
        if( dot_it != string::npos &&
            dot_it != 0 &&
            dot_it != current.size()-1 )
            offset = dot_it;
        m_ExtensionOffsets[i] = offset;
        
        
    
    }
}

#define __CHECK_BOUNDS( a ) \
    if( (a) >= m_ItemCount ) \
        throw out_of_range(string(__PRETTY_FUNCTION__) + ": index out of range");

bool VFSFlexibleListing::HasExtension(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    
    return m_ExtensionOffsets[_ind] != 0;
}

uint16_t VFSFlexibleListing::ExtensionOffset(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_ExtensionOffsets[_ind];
}

const char *VFSFlexibleListing::Extension(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Filenames[_ind].c_str() + m_ExtensionOffsets[_ind];
}

const string& VFSFlexibleListing::Filename(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Filenames[_ind];
}

CFStringRef VFSFlexibleListing::FilenameCF(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return *m_FilenamesCF[_ind];
}

const VFSHostPtr& VFSFlexibleListing::Host(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Hosts[_ind];
}

const string& VFSFlexibleListing::Directory(unsigned _ind) const
{
    __CHECK_BOUNDS(_ind);
    return m_Directories[_ind];
}

bool VFSFlexibleListing::HasCommonHost() const
{
    return m_Hosts.mode() == variable_container<>::type::common;
}

bool VFSFlexibleListing::HasCommonDirectory() const
{
    return m_Directories.mode() == variable_container<>::type::common;
}

//auto aa = []{
//    VFSFlexibleListingInput inp;
//    inp.directories[0] = "/";
//    inp.filenames.emplace_back("filename.txt");
//    
//    auto l = VFSFlexibleListing::Build(move(inp));
//    
//    l->Filename(0);
//    l->Filename(10);
//    
//    
//    
//    
//    
//    return 0;
//}();
