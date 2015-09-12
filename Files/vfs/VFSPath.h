//
//  VFSPath.h
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "VFSDeclarations.h"

class VFSPathStack
{
public:
    struct Part
    {
        Part() = default;
        Part(VFSHost &_host);
        
        const char* fs_tag; // this tag is redundant since configuration already able to provide it
        string junction;
        weak_ptr<VFSHost> host;
        VFSConfiguration configuration;

        /**
         * operation== performs fast comparison by ptrs.
         */
        bool operator==(const Part&_r) const;
        inline bool operator!=(const Part&_r) const { return !(*this == _r); }
        
        /**
         * Will compare parts without respect to host ptr and will compare options by it's content.
         */
        bool weak_equal(const Part&_r) const;
    };
    
    VFSPathStack();
    VFSPathStack(const VFSHostPtr &_vfs, const string &_path);
    
    inline bool operator==(const VFSPathStack& _r) const {
        return m_Stack == _r.m_Stack &&
        m_Path == _r.m_Path;
    }
    inline bool operator!=(const VFSPathStack& _r) const { return !(*this == _r); }
    inline const Part& operator[](size_t _n) const { return m_Stack[_n]; }
    inline bool empty() const {return m_Stack.empty(); }
    inline size_t size() const { return m_Stack.size(); }
    inline const Part& back() const { return m_Stack.back(); }
    inline const string& path() const { return m_Path; }
    bool weak_equal(const VFSPathStack&_r) const;
    string verbose_string() const;
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
            // we need to incorporate options somehow here. or not?
            str += "|"; // really need this?
        }
        str += _v.m_Path;
        return hash<string>()(str);
    }
};
