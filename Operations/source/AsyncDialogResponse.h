// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "ModalDialogResponses.h"
#include <any>
#include <mutex>
#include <condition_variable>
#include <optional>
#include <robin_hood.h>

namespace nc::ops {

struct AsyncDialogResponse {
    std::optional<long> response;
    robin_hood::unordered_map<std::string, std::any> messages;
    std::mutex lock;
    std::condition_variable blocker;

    void Abort() noexcept;
    void Commit(long _response) noexcept;
    void Wait() noexcept;

    void SetApplyToAll(bool _v = true);
    bool IsApplyToAllSet() noexcept;
};

} // namespace nc::ops
