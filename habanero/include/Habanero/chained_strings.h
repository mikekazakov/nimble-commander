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
#pragma once

#include <assert.h>
#include <string>

class chained_strings
{
    enum {
        strings_per_block   = 42,
        buffer_length       = 14,
        max_depth           = 128
    };

public:
    
#pragma pack(1)
    struct node
    {
    private:
        friend class chained_strings;

        union { // #0
            char buf[buffer_length];
            char *buf_ptr;
        };
        // UTF-8, including null-term. if .len >=buffer_length => buf_ptr is a buffer from malloc for .len+1 bytes
        
        unsigned short len; // #14
        // NB! not-including null-term (len for "abra" is 4, not 5!)
        
        const node *prefix; // #16
        // can be null. client must process it recursively to the root to get full string (to the element with .prefix = 0)
        // or just use str_with_pref function
        
    public:
        
        const char* c_str() const;
        unsigned short size() const;
        void str_with_pref(char *_buf) const;
        std::string to_str_with_pref() const;
    }; // 24 bytes long
#pragma pack()

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
                if(current == nullptr)
                    return true; // special case for empty containers
                
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
                if(current == nullptr)
                    return false; // special case for empty containers
                
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
    chained_strings(const std::string &_allocate_with_this_string);
    chained_strings(chained_strings&& _rhs);

    template<class T>
    inline chained_strings(std::initializer_list<T> l):
        m_Begin(nullptr),
        m_Last(nullptr)
    {
        construct();
        for(auto &i: l)
            push_back(i, nullptr);
    }
    
    ~chained_strings();
    
    inline iterator begin() const { return {m_Begin, 0}; }
    inline iterator end()   const { return {(block *)0xDEADBEEFDEADBEEF, (unsigned)-1}; }
    
    void push_back(const char *_str, unsigned _len, const node *_prefix);
    void push_back(const char *_str, const node *_prefix);
    void push_back(const std::string& _str, const node *_prefix);

    const node &front() const; // O(1)
    const node &back() const;  // O(1)
    bool empty() const;        // O(1)
    unsigned size() const;     // O(N) linear(!) time, N - number of blocks
    bool singleblock() const;  // O(1)
    
    void swap(chained_strings &_rhs);
    void swap(chained_strings &&_rhs);
    const chained_strings& operator=(chained_strings&&);
    
private:
    void insert_into(block *_to, const char *_str, unsigned _len, const node *_prefix);
    void construct();
    void destroy();
    void grow();
    chained_strings(const chained_strings&) = delete;
    void operator=(const chained_strings&) = delete;
    
    block *m_Begin;
    block *m_Last;
};


inline unsigned short chained_strings::node::size() const
{
    return len;
}

inline const char* chained_strings::node::c_str() const
{
    return len < buffer_length ? buf : buf_ptr;
}
