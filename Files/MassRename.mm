//
//  MassRename.cpp
//  Files
//
//  Created by Michael G. Kazakov on 29/04/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "MassRename.h"
#include "Common.h"

static optional<NSRange> Find(NSString *_str, MassRename::ApplyTo _what)
{
    using T = MassRename::ApplyTo;
    
    if( !_str )
        return nullopt;
    
    auto length = _str.length;
    
    if( _what == T::FullName ) {
        return NSMakeRange(0, length);
    }
    else {
        static auto cs = [NSCharacterSet characterSetWithCharactersInString:@"."];
        
        auto r = [_str rangeOfCharacterFromSet:cs options:NSBackwardsSearch];
        bool has_ext = (r.location != NSNotFound && r.location != 0);
        
        if( _what == T::Name ) {
            if( has_ext )
                return NSMakeRange(0, r.location);
            else
                return NSMakeRange(0, length);
        }
        else if( _what == T::Extension ) {
            if( has_ext )
                return NSMakeRange( r.location + 1, length - r.location - 1);
            else
                return nullopt;
        }
        else if( _what == T::ExtensionWithDot ) {
            if( has_ext )
                return NSMakeRange( r.location, length - r.location);
            else
                return nullopt;
        }
    }
    
    return nullopt;
}

static optional<NSRange> Find(const string &_str, MassRename::ApplyTo _what)
{
    using T = MassRename::ApplyTo;
    
    auto length = _str.length();
    
    if( _what == T::FullName ) {
        return NSMakeRange(0, length);
    }
    else {
        auto r = _str.find_last_of('.');
        bool has_ext = (r != string::npos && r != 0);

        if( _what == T::Name ) {
            if( has_ext )
                return NSMakeRange(0, r);
            else
                return NSMakeRange(0, length);
        }
        else if( _what == T::Extension ) {
            if( has_ext )
                return NSMakeRange( r + 1, length - r - 1);
            else
                return nullopt;
        }
        else if( _what == T::ExtensionWithDot ) {
            if( has_ext )
                return NSMakeRange( r, length - r );
            else
                return nullopt;
        }
    }
    
    return nullopt;
}

MassRename::ReplaceText::ReplaceText(const string& _replace_what,
                                     const string& _replace_with,
                                     ApplyTo _where,
                                     ReplaceMode _mode,
                                     bool _case_sensitive
                                     ):
    m_CaseSensitive(_case_sensitive),
    m_Where(_where),
    m_Mode(_mode),
    m_What([NSString stringWithUTF8StdString:_replace_what]),
    m_With([NSString stringWithUTF8StdString:_replace_with])
{
    /* TODO: in case of performance problems - implement a "dumb" algo for straight std::strings when _what and _with contains only ASCII symbols - no need to dive into NSString stuff  */
}

optional<string> MassRename::ReplaceText::Apply(const string& _filename, const FileInfo &_info) const
{
    auto str = [NSString stringWithUTF8StdStringNoCopy:_filename];
    
    auto part_if_any = Find(str, m_Where);
    if( !part_if_any )
        return nullopt;
    auto part = part_if_any.value();
    assert( part.location != NSNotFound );
    
    if( m_Mode == ReplaceMode::EveryOccurrence ) {
        NSMutableString *name = str.mutableCopy;
        auto num = [name replaceOccurrencesOfString:m_What
                                         withString:m_With
                                            options:(m_CaseSensitive ? 0 : NSCaseInsensitiveSearch)
                                              range:part];
        if(num > 0)
            return make_optional<string>(name.fileSystemRepresentationSafe);
        else
            return nullopt;
    }
    else if( m_Mode == ReplaceMode::FirstOccurrence ) {
        auto range = [str rangeOfString:m_What
                                options:(m_CaseSensitive ? 0 : NSCaseInsensitiveSearch)
                                  range:part];
        if( range.location != NSNotFound ) {
            auto newstr = [str stringByReplacingCharactersInRange:range
                                                       withString:m_With];
            return make_optional<string>(newstr.fileSystemRepresentationSafe);
        }
        else
            return nullopt;
    }
    else if( m_Mode == ReplaceMode::LastOccurrence ) {
        auto range = [str rangeOfString:m_What
                                options:(m_CaseSensitive ? 0 : NSCaseInsensitiveSearch) | NSBackwardsSearch
                                  range:part];
        if( range.location != NSNotFound ) {
            auto newstr = [str stringByReplacingCharactersInRange:range
                                                       withString:m_With];
            return make_optional<string>(newstr.fileSystemRepresentationSafe);
        }
        else
            return nullopt;
    }
    else if( m_Mode == ReplaceMode::WholeText ) {
        auto newstr = [str stringByReplacingCharactersInRange:part
                                                   withString:m_With];
        return make_optional<string>(newstr.fileSystemRepresentationSafe);
    }
    
    return nullopt;
}

MassRename::AddText::AddText(const string& _add_what,
                             ApplyTo _where,
                             Position _at):
    m_What(_add_what),
    m_At(_at),
    m_Where(_where)
{
}

optional<string> MassRename::AddText::Apply(const string& _filename, const FileInfo &_info) const
{
    auto part_if_any = Find(_filename, m_Where);
    if( !part_if_any )
        return nullopt;
    auto part = part_if_any.value();
    assert( part.location != NSNotFound );
    
    string str = _filename;
    
    if( m_At == Position::Beginning )
        str.insert( part.location, m_What );
    else
        str.insert( part.location + part.length, m_What);
    
    return str;
}

void MassRename::ResetActions()
{
    m_Actions.clear();
}

void MassRename::AddAction( const MassRename::Action &_a )
{
    m_Actions.emplace_back(_a);
}

vector<string> MassRename::Rename(const VFSListing& _listing, const vector<unsigned>& _inds)
{
    vector<string> filenames;
    vector<FileInfo> infos;
    
    unsigned num = 0;
    for( auto i: _inds ) {
        auto &e = _listing[i];
        
        FileInfo fi;
        fi.size = e.Size();
        fi.number = num++;
        infos.emplace_back(fi);
        
        filenames.emplace_back(e.Name());
    }
    
    for(size_t i = 0, e = filenames.size(); i != e; ++i) {
        for( auto &a: m_Actions ) {
            auto newstr = a.Apply(filenames[i], infos[i]);
            
            if(newstr)
                filenames[i] = newstr.value();
        }
    }
    
    return filenames;
}
