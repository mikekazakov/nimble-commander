//
//  VFSPath.h
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

class VFSListing;
class VFSHost;

class VFSPathStack
{
public:
    struct Part
    {
        const char* fs_tag;
        /* string fs_opt; - later: params for network fs etc */
        string junction;
        weak_ptr<VFSHost> host;
        
        inline bool operator==(const Part&_r) const {
            return fs_tag == _r.fs_tag &&
                    junction == _r.junction &&
                    !host.owner_before(_r.host) && !_r.host.owner_before(host); // tricky weak_ptr comparison
        }
        inline bool operator!=(const Part&_r) const { return !(*this == _r); }
    };
    
    VFSPathStack(shared_ptr<VFSListing> _listing);
    VFSPathStack(const VFSPathStack&_r);
    VFSPathStack(VFSPathStack&&_r);
    
    inline bool operator==(const VFSPathStack& _r) const {
        return m_Stack == _r.m_Stack &&
        m_Path == _r.m_Path;
    }
    inline bool operator!=(const VFSPathStack& _r) const { return !(*this == _r); }
    const Part& operator[](size_t _n) const { return m_Stack[_n]; }
    inline bool empty() const {return m_Stack.empty(); }
    inline size_t size() const { return m_Stack.size(); }
    const Part& back() const { return m_Stack.back(); }
private:
    friend struct hash<VFSPathStack>;
    vector<Part>    m_Stack;
    string          m_Path;
};

// calculating hash() of VFSPathStack
template<>
struct hash<VFSPathStack>
{
    typedef VFSPathStack argument_type;
    typedef std::size_t value_type;
        
    value_type operator()(argument_type const& _v) const
    {
        string str;
        for(auto &i:_v.m_Stack)
        {
            str += i.fs_tag;
            str += i.junction;
            str += "|"; // really need this?
        }
        str += _v.m_Path;
        
        hash<string> h;
        return h(str);
    }
};
