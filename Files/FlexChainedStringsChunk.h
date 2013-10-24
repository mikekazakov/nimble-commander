//
//  FlexChainedStringsChunk.h
//  Directories
//
//  Created by Michael G. Kazakov on 13.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <assert.h>
#include <string.h>

struct FlexChainedStringsChunk
{
    enum {strings_per_chunk = 42, buflen=14, maxdepth=128};
    
    // #0 bytes offset
    struct node
    {
        char buf[buflen];   // #0
        // UTF-8, including null-term. if .len >=buflen => (char**)&str[0] is a buffer from malloc for .len+1 bytes
        unsigned short len; // #14
        // NB! not-including null-term (len for "abra" is 4, not 5!)
        const node *prefix; // #16
        // can be null. client must process it recursively to the root to get full string (to the element with .prefix = 0)
        // or just use str_with_pref function
        
        inline const char* str() const
        {
            if(len < buflen)
                return buf;
            return *(const char**)(&buf[0]);
        }
        
        void str_with_pref(char *_buf) const;
    };

private:
    node strings[strings_per_chunk];
    // 24 * strings_per_chunk bytes. assume it's 24*42 = 1008 bytes
    
    // #1008  bytes offset
    unsigned amount;
    
    // #1012
    char _______padding[4];
    
    // #1016 bytes offset
    FlexChainedStringsChunk *next;
    // next is valid pointer when .amount == strings_per_chunk, otherwise it should be null

public:
    
    // allocate and free. nuff said.
    static FlexChainedStringsChunk* Allocate();
    static FlexChainedStringsChunk* AllocateWithSingleString(const char *_str);
    static void FreeWithDescendants(FlexChainedStringsChunk** _first_chunk);
    
    void FreeWithDescendants() { FlexChainedStringsChunk* p = this; FreeWithDescendants(&p); }
    
    /**
     * AddString return a chunk in which _str was inserted.
     * It can be "this" if there was a space here, or it can be a freshly allocated descendant, which is linked with .next field.
     * To immediately accest lastly inserted string, use back() method or directly operator[Amount()-1].
     * _len field is used for minor run-time speedup.
     */
    FlexChainedStringsChunk* AddString(const char *_str, unsigned _len, const node *_prefix);
    
    /**
     * AddString return a chunk in which _str was inserted.
     * It can be "this" if there was a space here, or it can be a freshly allocated descendant, which is linked with .next field.
     * To immediately accest lastly inserted string, use back() method or directly operator[Amount()-1].
     */
    FlexChainedStringsChunk* AddString(const char *_str, const node *_prefix);
    
    // return amount of strings in current chunk
    inline unsigned Amount() const {return amount; }
    
    // return total amount of string in with chunk plus within all linked after it
    unsigned CountStringsWithDescendants() const;
    
    inline const node& operator[](unsigned _n) const
    {
        assert(_n < amount);
        return strings[_n];
    }
    
    struct iterator
    {
        const FlexChainedStringsChunk *current;
        unsigned index;
        inline void operator++()
        {
            index++;
            assert(index <= current->amount);            
            if(index == strings_per_chunk && current->next != 0)
            {
                index = 0;
                current = current->next;
            }
        }
        inline bool operator==(const iterator& _right) const
        {
            if(_right.current == (FlexChainedStringsChunk *)0xDEADBEEFDEADBEEF)
            { // caller asked us if we're finished
                assert(index <= current->amount);
                return index == current->amount;
            }
            else
                return current == _right.current && index == _right.index;
        }
        
        inline bool operator!=(const iterator& _right) const
        {
            if(_right.current == (FlexChainedStringsChunk *)0xDEADBEEFDEADBEEF)
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
    
    inline iterator begin() const { return {this, 0}; }
    inline iterator end()   const { return {(FlexChainedStringsChunk *)0xDEADBEEFDEADBEEF, (unsigned)-1}; }
    inline const FlexChainedStringsChunk::node &back() const { assert(amount > 0); return strings[amount-1]; }
        
private:
    FlexChainedStringsChunk();                        // no implementation
    ~FlexChainedStringsChunk();                       // no implementation
    FlexChainedStringsChunk(const FlexChainedStringsChunk&); // no implementation
    void operator=(const FlexChainedStringsChunk&);   // no implementation
    
}; // sizeof(FlexStringsChunk) == 1024


inline FlexChainedStringsChunk* FlexChainedStringsChunk::AddString(const char *_str, const node *_prefix)
{
    return AddString(_str, (unsigned) strlen(_str), _prefix);
}
