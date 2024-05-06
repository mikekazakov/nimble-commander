// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>
#include <filesystem>
#include <functional>
#include <memory>

namespace nc::utility {

// sends notifications about file-level updates based the FSEvents framework
class FSEventsFileUpdate
{
public:
    virtual ~FSEventsFileUpdate() = default;

    // adds a watcher for the file named _path and incorporates _handler to be called once a file at
    // _path is changed. returns a token identifying the watch. zero value means an error, any
    // others - valid observation tokens.
    // callbacks shall not access this object back as an implementation is not required to be
    // reenterant.
    // the order in which the callbacks for the same path will be called is not guaranteed.
    virtual uint64_t AddWatchPath(const std::filesystem::path &_path, std::function<void()> _handler) = 0;

    // registers the watch identified by _token.
    virtual void RemoveWatchPathWithToken(uint64_t _token) = 0;

    // a token with with this (zero) value is interpreted as invalid.
    constexpr static inline uint64_t empty_token = 0;
};

} // namespace nc::utility
