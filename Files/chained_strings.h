//
//  FlexChainedStringsChunk.h
//  Directories
//
//  Created by Michael G. Kazakov on 13.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <assert.h>
#include <string>

using namespace std;

class chained_strings
{
    enum {
        strings_per_block   = 42,
        buffer_length       = 14,
        max_depth           = 128
    };

public:
    // #0 bytes offset
    struct node
    {
        char buf[buffer_length];   // #0
        // UTF-8, including null-term. if .len >=buffer_length => (char**)&str[0] is a buffer from malloc for .len+1 bytes
        
        unsigned short len; // #14
        // NB! not-including null-term (len for "abra" is 4, not 5!)
        
        const node *prefix; // #16
        // can be null. client must process it recursively to the root to get full string (to the element with .prefix = 0)
        // or just use str_with_pref function
        
        const char* str() const;
        void str_with_pref(char *_buf) const;
    }; // 24 bytes long
    
private:
    struct block
    { // keep 'hot' data first
        unsigned amount;                    // #0
        block *next;                        // #8
        // next is valid pointer when .amount == strings_per_block, otherwise it should be null
        node strings[strings_per_block];    // # 16
    }; // 1024 bytes long

public:
    struct iterator
    {
        const block *current;
        unsigned index;
        inline void operator++()
        {
            index++;
            assert(index <= current->amount);
            if(index == strings_per_block && current->next != 0)
            {
                index = 0;
                current = current->next;
            }
        }
        inline bool operator==(const iterator& _right) const
        {
            if(_right.current == (block *)0xDEADBEEFDEADBEEF)
            { // caller asked us if we're finished
                assert(index <= current->amount);
                return index == current->amount;
            }
            else
                return current == _right.current && index == _right.index;
        }
        
        inline bool operator!=(const iterator& _right) const
        {
            if(_right.current == (block *)0xDEADBEEFDEADBEEF)
            { // caller asked us if we're finished
                assert(index <= current->amount);
                return index < current->amount;
            }
            else
                return current != _right.current || index != _right.index;
        }
        
        inline const node& operator*() const
        {
            assert(index <= current->amount);
            return current->strings[index];
        }
    };
    
    chained_strings();
    chained_strings(const char *_allocate_with_this_string);
    chained_strings(const string &_allocate_with_this_string);
    chained_strings(chained_strings&& _rhs);
    ~chained_strings();
    
    inline iterator begin() const { return {m_Begin, 0}; }
    inline iterator end()   const { return {(block *)0xDEADBEEFDEADBEEF, (unsigned)-1}; }
    
    void push_back(const char *_str, unsigned _len, const node *_prefix);
    void push_back(const char *_str, const node *_prefix);
    void push_back(const string& _str, const node *_prefix);

    const node &front() const;
    const node &back() const;
    bool empty() const;
    unsigned size() const; // linear(!) time

    
    void swap(chained_strings &_rhs);
    void swap(chained_strings &&_rhs);
private:
    void insert_into(block *_to, const char *_str, unsigned _len, const node *_prefix);
    void construct();
    void grow();
    chained_strings(const chained_strings&) = delete;
    void operator=(const chained_strings&) = delete;
    
    block *m_Begin;
    block *m_Last;
};

inline const char* chained_strings::node::str() const
{
    if(len < buffer_length)
        return buf;
    return *(const char**)(&buf[0]);
}
