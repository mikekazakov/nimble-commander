/* Copyright (c) 2013 Michael G. Kazakov
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#include <stdlib.h>
#include <memory.h>
#include <Habanero/chained_strings.h>

chained_strings::chained_strings():
    m_Begin(nullptr),
    m_Last(nullptr)
{
    static_assert(sizeof(node)  == 24,   "size of string node should be 14 bytes");
    static_assert(sizeof(block) == 1024, "size of strings chunk should be 1024 bytes");
}

chained_strings::chained_strings(const char *_allocate_with_this_string):
    m_Begin(nullptr),
    m_Last(nullptr)
{
    construct();
    push_back(_allocate_with_this_string, nullptr);
}

chained_strings::chained_strings(const std::string &_allocate_with_this_string):
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
    destroy();
}

void chained_strings::destroy()
{
    auto curr = m_Begin;
    while(curr != nullptr) {
        auto next = curr->next;
        for(int i = 0; i < curr->amount; ++i)
            if(curr->strings[i].len >= buffer_length)
                free(curr->strings[i].buf_ptr);
        free(curr);
        curr = next;
    }
    m_Begin = m_Last = nullptr;
}

void chained_strings::push_back(const char *_str, unsigned _len, const node *_prefix)
{
    if(_str == nullptr)
        throw std::exception();
    
    if(m_Last == nullptr)
        construct();
    
    if(m_Last->amount == strings_per_block)
        grow();
    
    insert_into(m_Last, _str, _len, _prefix);
}

void chained_strings::push_back(const char *_str, const node *_prefix)
{
    if(_str == nullptr)
        throw std::exception();
    
    push_back(_str, (unsigned)strlen(_str), _prefix);
}

void chained_strings::push_back(const std::string& _str, const node *_prefix)
{
    push_back(_str.c_str(), (unsigned) _str.length(), _prefix);
}

void chained_strings::insert_into(block *_to, const char *_str, unsigned _len, const node *_prefix)
{
    assert(_to->amount < strings_per_block);
    auto &node = _to->strings[_to->amount];
    node.len = _len;
    node.prefix = _prefix;
    if(_len < buffer_length) {
        memcpy(node.buf, _str, _len+1);
    }
    else {
        char *news = (char*)malloc(_len+1);
        memcpy(news, _str, _len+1);
        node.buf_ptr = news;
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
    assert(curr->amount == strings_per_block);
    
    auto fresh = (block*) malloc(sizeof(block));
    memset(fresh, 0, sizeof(block));
    
    curr->next = fresh;
    m_Last = fresh;
}

const chained_strings::node &chained_strings::front() const
{
    if( m_Begin == nullptr)
        throw std::exception();

    assert(m_Begin->amount > 0);
    return m_Begin->strings[0];
}

const chained_strings::node &chained_strings::back() const
{
    if( m_Last == nullptr)
        throw std::exception();
    
    assert(m_Last->amount > 0);
    return m_Last->strings[m_Last->amount-1];
}

void chained_strings::node::str_with_pref(char *_buf) const
{
    const node *nodes[max_depth], *n = this;
    int bufsz = 0, nodes_n = 0;
    do
    {
        nodes[nodes_n++] = n;
        assert(nodes_n < max_depth);
    } while( (n = n->prefix) != 0 );
    
    for(int i = nodes_n-1; i >= 0; --i)
    {
        memcpy(_buf + bufsz, nodes[i]->c_str(), nodes[i]->len);
        bufsz += nodes[i]->len;
    }
    _buf[bufsz] = 0;
}

std::string chained_strings::node::to_str_with_pref() const
{
    const node *nodes[max_depth], *n = this;
    int bufsz = 0, nodes_n = 0;
    do
    {
        bufsz += n->len;
        nodes[nodes_n++] = n;
        assert(nodes_n < max_depth);
    } while( (n = n->prefix) != 0 );
    
    std::string res;
    res.reserve(bufsz);
    for(int i = nodes_n-1; i >= 0; --i)
        res.append(nodes[i]->c_str(), nodes[i]->len);

    return res;
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

bool chained_strings::singleblock() const
{
    return m_Begin != nullptr &&
           m_Begin == m_Last;
}

void chained_strings::swap(chained_strings &_rhs)
{
    std::swap(m_Begin, _rhs.m_Begin);
    std::swap(m_Last, _rhs.m_Last);
}

void chained_strings::swap(chained_strings &&_rhs)
{
    std::swap(m_Begin, _rhs.m_Begin);
    std::swap(m_Last, _rhs.m_Last);
}

const chained_strings& chained_strings::operator=(chained_strings&& _rhs)
{
    destroy();
    m_Begin = _rhs.m_Begin;
    m_Last = _rhs.m_Last;
    _rhs.m_Begin = nullptr;
    _rhs.m_Last = nullptr;
    return *this;
}
