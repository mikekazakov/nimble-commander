//
//  FlexChainedStringsChunk.h
//  Directories
//
//  Created by Michael G. Kazakov on 13.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once


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
    } strings[strings_per_chunk];
    // 24 * strings_per_chunk bytes. assume it's 24*42 = 1008 bytes
    
    // #1008  bytes offset
    unsigned amount;
    
    // #1012
    char _______padding[4];
    
    // #1016 bytes offset
    FlexChainedStringsChunk *next;
    // next is valid pointer when .amount == strings_per_chunk, otherwise it should be null
    
    
    // allocate and free. nuff said.
    static FlexChainedStringsChunk* Allocate();
    static void FreeWithDescendants(FlexChainedStringsChunk** _first_chunk);
    
    // AddString return a chunk in which _str was inserted
    // it can be "this" if there was a space here, or it can be a freshly allocated descendant,
    // which is linked with .next field
    FlexChainedStringsChunk* AddString(const char *_str, int _len, const node *_prefix);
    
    FlexChainedStringsChunk* AddString(const char *_str, const node *_prefix);
    
private:
    FlexChainedStringsChunk();                        // no implementation
    ~FlexChainedStringsChunk();                       // no implementation
    FlexChainedStringsChunk(const FlexChainedStringsChunk&); // no implementation
    void operator=(const FlexChainedStringsChunk&);   // no implementation
    
}; // sizeof(FlexStringsChunk) == 1024
