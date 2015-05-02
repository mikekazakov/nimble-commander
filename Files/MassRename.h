//
//  MassRename.h
//  Files
//
//  Created by Michael G. Kazakov on 29/04/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "PanelData.h"

// - replace text
// - replace with regexp
// - add text
// - change text
// - add sequence
// - add modification date
// - add creation date
// - trim?
// - add ext program output?

class MassRename
{
public:
    class Action;
    class ReplaceText;
    class AddText;
    
    
    enum class ApplyTo
    {
        FullName            = 0,
        Name                = 1,
        Extension           = 2,
        ExtensionWithDot    = 3
    };
    
    enum class Position
    {
        Beginning           = 0,
        Ending              = 1
    };
    
    struct FileInfo
    {
        // filesize, date, #index etc
        unsigned number;
        uint64_t size;
        
        
    };
    
    void ResetActions();
    void AddAction( const Action &_a );
    
    vector<string> Rename(const VFSListing& _listing, const vector<unsigned>& _inds);
    
private:
    vector<Action>                      m_Actions;
};

class MassRename::Action
{
public:
    template <class T>
    Action(T _obj): action( make_shared<Model<T>>(move(_obj)) ) {}
    
    optional<string> Apply(const string& _filename, const FileInfo &_info) const
    {
        return action->Apply(_filename, _info);
    }
    
private:
    struct Concept
    {
        virtual ~Concept() = default;
        virtual optional<string> Apply(const string& _filename, const FileInfo &_info) const = 0;
    };
    
    template <class T>
    struct Model : Concept
    {
        Model(T _obj): obj( move(_obj) ) {}
        
        optional<string> Apply(const string& _filename, const FileInfo &_info) const
        {
            return obj.Apply(_filename, _info);
        }
        
        T obj;
    };
    
    shared_ptr<const Concept> action;
};


class MassRename::ReplaceText
{
public:
    enum class ReplaceMode
    {
        FirstOccurrence = 0,
        LastOccurrence  = 1,
        EveryOccurrence = 2,
        WholeText       = 3
    };
    ReplaceText(const string& _replace_what,
                const string& _replace_with,
                ApplyTo _where,
                ReplaceMode _mode,
                bool _case_sensitive);
    optional<string> Apply(const string& _filename, const FileInfo &_info) const;
    
private:
    NSString *m_What;
    NSString *m_With;
    ApplyTo m_Where;
    ReplaceMode m_Mode;
    bool m_CaseSensitive;
};

class MassRename::AddText
{
public:
    AddText(const string& _add_what,
            ApplyTo _where,
            Position _at);
    optional<string> Apply(const string& _filename, const FileInfo &_info) const;
    
private:
    string m_What;
    ApplyTo m_Where;
    Position m_At;
};