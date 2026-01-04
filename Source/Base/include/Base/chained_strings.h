// Copyright (C) 2013-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <assert.h>
#include <string>

namespace nc::base {

class chained_strings
{
    static constexpr size_t strings_per_block = 42;
    static constexpr size_t buffer_length = 14;
    static constexpr size_t max_depth = 128;

public:
#pragma pack(1)
    struct node {
    private:
        friend class chained_strings;

        union { // #0
            char buf[buffer_length];
            char *buf_ptr;
        };
        // UTF-8, including null-term. if .len >=buffer_length => buf_ptr is a buffer from malloc
        // for .len+1 bytes

        unsigned short len; // #14
        // NB! not-including null-term (len for "abra" is 4, not 5!)

        const node *prefix; // #16
        // can be null. client must process it recursively to the root to get full string (to the
        // element with .prefix = 0) or just use str_with_pref function

    public:
        [[nodiscard]] const char *c_str() const;
        [[nodiscard]] unsigned short size() const;
        void str_with_pref(char *_buf) const;
        [[nodiscard]] std::string to_str_with_pref() const;
    }; // 24 bytes long
#pragma pack()

private:
    struct block {       // keep 'hot' data first
        unsigned amount; // #0
        block *next;     // #8
        // next is valid pointer when .amount == strings_per_block, otherwise it should be null
        node strings[strings_per_block]; // # 16
    }; // 1024 bytes long

    inline static block *const m_Sentinel = reinterpret_cast<block *>(0xDEADBEEFDEADBEEF);

public:
    struct iterator {
        const block *current;
        unsigned index;
        void operator++()
        {
            index++;
            assert(index <= current->amount);
            if( index == strings_per_block && current->next != nullptr ) {
                index = 0;
                current = current->next;
            }
        }
        bool operator==(const iterator &_right) const
        {
            if( _right.current == m_Sentinel ) { // caller asked us if we're finished
                if( current == nullptr )
                    return true; // special case for empty containers

                assert(index <= current->amount);
                return index == current->amount;
            }
            else
                return current == _right.current && index == _right.index;
        }

        bool operator!=(const iterator &_right) const
        {
            if( _right.current == m_Sentinel ) { // caller asked us if we're finished
                if( current == nullptr )
                    return false; // special case for empty containers

                assert(index <= current->amount);
                return index < current->amount;
            }
            else
                return current != _right.current || index != _right.index;
        }

        const node &operator*() const
        {
            assert(index <= current->amount);
            return current->strings[index];
        }
    };

    chained_strings();
    chained_strings(const char *_allocate_with_this_string);
    chained_strings(const std::string &_allocate_with_this_string);
    chained_strings(const chained_strings &) = delete;
    chained_strings(chained_strings &&_rhs) noexcept;

    template <class T>
    chained_strings(std::initializer_list<T> l) : m_Begin(nullptr), m_Last(nullptr)
    {
        construct();
        for( auto &i : l )
            push_back(i, nullptr);
    }

    ~chained_strings();

    void operator=(const chained_strings &) = delete;
    chained_strings &operator=(chained_strings && /*_rhs*/) noexcept;

    [[nodiscard]] iterator begin() const { return {.current = m_Begin, .index = 0}; }
    [[nodiscard]] static iterator end() { return {.current = m_Sentinel, .index = static_cast<unsigned>(-1)}; }

    void push_back(const char *_str, unsigned _len, const node *_prefix);
    void push_back(const char *_str, const node *_prefix);
    void push_back(const std::string &_str, const node *_prefix);

    [[nodiscard]] const node &front() const; // O(1)
    [[nodiscard]] const node &back() const;  // O(1)
    [[nodiscard]] bool empty() const;        // O(1)
    [[nodiscard]] unsigned size() const;     // O(N) linear(!) time, N - number of blocks
    [[nodiscard]] bool singleblock() const;  // O(1)

    void swap(chained_strings &_rhs) noexcept;

private:
    static void insert_into(block *_to, const char *_str, unsigned _len, const node *_prefix);
    void construct();
    void destroy();
    void grow();

    block *m_Begin;
    block *m_Last;
};

inline unsigned short chained_strings::node::size() const
{
    return len;
}

inline const char *chained_strings::node::c_str() const
{
    return len < buffer_length ? buf : buf_ptr;
}

} // namespace nc::base
