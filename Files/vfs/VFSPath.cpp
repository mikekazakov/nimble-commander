//
//  VFSPath.mm
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFS.h"

VFSPathStack::Part::Part(VFSHost &_host):
    fs_tag(_host.FSTag()),
    junction(_host.JunctionPath()),
    host(_host.shared_from_this()),
    configuration(_host.Configuration())
{
}

bool VFSPathStack::Part::operator==(const Part&_r) const
{
    return fs_tag == _r.fs_tag &&
            junction == _r.junction &&
            !host.owner_before(_r.host) && !_r.host.owner_before(host) && // tricky weak_ptr comparison
            configuration == _r.configuration
            ;
}

bool VFSPathStack::Part::weak_equal(const Part&_r) const
{
    if(*this == _r)
        return true;
       
    if(fs_tag != _r.fs_tag) return false;
    if(junction != _r.junction) return false;
    if(configuration != _r.configuration ) return false;
    return true;
}

VFSPathStack::VFSPathStack()
{
}

VFSPathStack::VFSPathStack(const VFSHostPtr &_vfs, const string &_path):
    m_Path(_path)
{
    auto curr_host = _vfs.get();
    while( curr_host != nullptr  ) {
        m_Stack.emplace_back( *curr_host );
        curr_host = curr_host->Parent().get();
    }
    reverse(begin(m_Stack), end(m_Stack));
}

bool VFSPathStack::weak_equal(const VFSPathStack&_r) const
{
    if(m_Stack.size() != _r.m_Stack.size()) return false;
    if(m_Path != _r.m_Path) return false;
    auto i = begin(m_Stack), j = begin(_r.m_Stack), e = end(m_Stack);
    for(;i != e; ++i, ++j)
        if(!i->weak_equal(*j))
            return false;
    return true;
}

string VFSPathStack::verbose_string() const
{
    string res;
    for( auto &i: m_Stack )
        res += i.configuration.VerboseJunction();
    res += m_Path;
    return res;
}
