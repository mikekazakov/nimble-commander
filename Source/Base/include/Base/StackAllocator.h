// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <memory_resource>

namespace nc {

template <size_t size>
class BasicStackAllocator : public std::pmr::monotonic_buffer_resource
{
public:
    BasicStackAllocator() : std::pmr::monotonic_buffer_resource(m_Buffer, size) {}

private:
    char m_Buffer[size];
};

using StackAllocator = BasicStackAllocator<4096>;

} // namespace nc
