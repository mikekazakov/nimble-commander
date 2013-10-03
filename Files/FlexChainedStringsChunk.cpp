//
//  FlexChainedStringsChunk.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 13.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "FlexChainedStringsChunk.h"
#include <assert.h>
#include <stdlib.h>
#include <memory.h>

// TODO: add _buf max length as parameter to prevent memory corruption
void FlexChainedStringsChunk::node::str_with_pref(char *_buf) const
{
    const FlexChainedStringsChunk::node *nodes[maxdepth], *n = this;
    int bufsz = 0, nodes_n = 0;
    do
    {
        nodes[nodes_n++] = n;
        assert(nodes_n < maxdepth);
    } while( (n = n->prefix) != 0 );
    
    for(int i = nodes_n-1; i >= 0; --i)
    {
        memcpy(_buf + bufsz, nodes[i]->str(), nodes[i]->len);
        bufsz += nodes[i]->len;
    }
    _buf[bufsz] = 0;
}

FlexChainedStringsChunk* FlexChainedStringsChunk::Allocate()
{
    assert(sizeof(FlexChainedStringsChunk) == 1024);
    FlexChainedStringsChunk *c = (FlexChainedStringsChunk*) malloc(sizeof(FlexChainedStringsChunk));
    memset(c, 0, sizeof(FlexChainedStringsChunk));
    return c;
}

FlexChainedStringsChunk* FlexChainedStringsChunk::AllocateWithSingleString(const char *_str)
{
    FlexChainedStringsChunk *chunk = Allocate();
    chunk->AddString(_str, 0);
    return chunk;
}

void FlexChainedStringsChunk::FreeWithDescendants(FlexChainedStringsChunk** _first_chunk)
{
    assert(_first_chunk != 0);
    assert(*_first_chunk != 0);
    FlexChainedStringsChunk *current = *_first_chunk;
    *_first_chunk = 0;

    do
    {
        FlexChainedStringsChunk *next = current->next;
        for(int i = 0; i < current->amount; ++i)
            if(current->strings[i].len >= buflen)
                free( *(char**)(&current->strings[i].buf[0]) );
    
        free(current);
        current = next;
    }  while(current != 0);
}

FlexChainedStringsChunk* FlexChainedStringsChunk::AddString(const char *_str, int _len, const node *_prefix)
{
    // check for available space in current chunk
    if(amount < strings_per_chunk)
    { // ok to add string in current chunk
        strings[amount].len = _len;
        strings[amount].prefix = _prefix;
        if(_len < buflen)
        {
            memcpy(strings[amount].buf, _str, _len+1);
        }
        else
        {
            char *news = (char*)malloc(_len+1);
            memcpy(news, _str, _len+1);
            *(char**)(&strings[amount].buf[0]) = news;
        }
        amount++;
        return this;
    }
    else
    { // need to allocate a new descendant
        assert(next == 0);
        // will assert on trying to add string to a full chunk twise -
        // client should use a value returned by last AddString call
        next = Allocate();
        return next->AddString(_str, _prefix);
    }
}

FlexChainedStringsChunk* FlexChainedStringsChunk::AddString(const char *_str, const node *_prefix)
{
    return AddString(_str, (int)strlen(_str), _prefix);
}

unsigned FlexChainedStringsChunk::CountStringsWithDescendants() const
{
    unsigned stock = 0;
    const FlexChainedStringsChunk *p = this;
    while(p)
    {
        stock += p->amount;
        p = p->next;
    }
    return stock;
}

