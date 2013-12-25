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

#if 0

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

FlexChainedStringsChunk* FlexChainedStringsChunk::AddString(const char *_str, unsigned _len, const node *_prefix)
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

#endif

////////////////////////////////////////////////////////////////////////////////

chained_strings::chained_strings():
    m_Begin(nullptr),
    m_Last(nullptr)
{
//    static_assert(sizeof(node) == 1024, "size of strings chunk should be 1024 bytes");
}

chained_strings::chained_strings(const char *_allocate_with_this_string):
    m_Begin(nullptr),
    m_Last(nullptr)
{
    construct();
    push_back(_allocate_with_this_string, nullptr);
}

chained_strings::chained_strings(const string &_allocate_with_this_string):
    m_Begin(nullptr),
    m_Last(nullptr)
{
    construct();
    push_back(_allocate_with_this_string, nullptr);
}

chained_strings::chained_strings(chained_strings&& _rhs):
    m_Begin(_rhs.m_Begin),
    m_Last(_rhs.m_Last)
{
    _rhs.m_Begin = _rhs.m_Last = 0;
}

chained_strings::~chained_strings()
{
    auto curr = m_Begin;
    while(curr != nullptr) {
        auto next = curr->next;
        for(int i = 0; i < curr->amount; ++i)
            if(curr->strings[i].len >= buflen)
                free( *(char**)(&curr->strings[i].buf[0]) );
        free(curr);
        curr = next;
    }
}

void chained_strings::push_back(const char *_str, unsigned _len, const node *_prefix)
{
    if(m_Last == nullptr)
        construct();
    
    if(m_Last->amount == strings_per_chunk)
        grow();
    
    insert_into(m_Last, _str, _len, _prefix);
}

void chained_strings::push_back(const char *_str, const node *_prefix)
{
    push_back(_str, (unsigned)strlen(_str), _prefix);
}

void chained_strings::push_back(const string& _str, const node *_prefix)
{
    push_back(_str.c_str(), (unsigned) _str.length(), _prefix);
}

void chained_strings::insert_into(block *_to, const char *_str, unsigned _len, const node *_prefix)
{
    assert(_to->amount < strings_per_chunk);
    auto &node = _to->strings[_to->amount];
    node.len = _len;
    node.prefix = _prefix;
    if(_len < buflen) {
        memcpy(node.buf, _str, _len+1);
    }
    else {
        char *news = (char*)malloc(_len+1);
        memcpy(news, _str, _len+1);
        *(char**)(&node.buf[0]) = news;
    }
    _to->amount++;
}

void chained_strings::construct()
{
    assert(m_Begin == nullptr);
    assert(m_Last == nullptr);
    
    m_Begin = m_Last = (block*) malloc(sizeof(block));
    memset(m_Begin, 0, sizeof(block));
}

void chained_strings::grow()
{
    assert(m_Last != nullptr);
    assert(m_Begin != nullptr);
    
    auto curr = m_Last;
    assert(curr->amount == strings_per_chunk);
    
    auto fresh = (block*) malloc(sizeof(block));
    memset(fresh, 0, sizeof(block));
    
    curr->next = fresh;
    m_Last = fresh;
}

const chained_strings::node &chained_strings::front() const
{
    assert(m_Begin != nullptr);
    assert(m_Begin->amount > 0);
    return m_Begin->strings[0];
}

const chained_strings::node &chained_strings::back() const
{
    assert(m_Last != nullptr);
    assert(m_Last->amount > 0);    
    return m_Last->strings[m_Last->amount-1];
}

void chained_strings::node::str_with_pref(char *_buf) const
{
    const node *nodes[maxdepth], *n = this;
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

bool chained_strings::empty() const
{
    return m_Begin == nullptr;
}

unsigned chained_strings::size() const
{
    unsigned stock = 0;
    auto *p = m_Begin;
    while(p) {
        stock += p->amount;
        p = p->next;
    }
    return stock;
}

void chained_strings::swap(chained_strings &_rhs)
{
    ::swap(m_Begin, _rhs.m_Begin);
    ::swap(m_Last, _rhs.m_Last);
}

void chained_strings::swap(chained_strings &&_rhs)
{
    ::swap(m_Begin, _rhs.m_Begin);
    ::swap(m_Last, _rhs.m_Last);    
}
