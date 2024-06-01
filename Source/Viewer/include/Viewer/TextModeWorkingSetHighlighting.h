// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "TextModeWorkingSet.h"
#include "Highlighting/Style.h"
#include <span>
#include <functional>
#include <string>
#include <chrono>

namespace nc::viewer {

class TextModeWorkingSetHighlighting : public std::enable_shared_from_this<TextModeWorkingSetHighlighting>
{
public:
    enum class Status : uint8_t {
        // Highlighting wasn't started yet
        Inactive,

        // Highlighting is in progress
        Working,

        // Highlighting is done
        Done
    };

    // Creates a highlighting object for the given working set and the highlighting options.
    // Both arguments are required
    TextModeWorkingSetHighlighting(std::shared_ptr<const TextModeWorkingSet> _working_set,
                                   std::shared_ptr<const std::string> _highlighting_options);

    // Returns an array containing styles per each character of the working set.
    // Initially filled with Style::Default, it will be filled with actual styles once highlighting is sucessfuly done.
    std::span<const hl::Style> Styles() const noexcept;

    // Returns the working set this highlighting is associated with.
    std::shared_ptr<const TextModeWorkingSet> WorkingSet() const noexcept;

    // Returns the current status of the highlighting process.
    enum Status Status() const noexcept;

    // Request to syntax highlight the text from the working set.
    // The method can spent up to '_sync_timeout' to wait for the result in a blocking manner, after which it falls
    // back to an async continuation.
    // In any case _on_highlighted will be called once highlighting is done, which might be later or during the call to
    // this method.
    // Highlighting can be requested only once per object.
    void Highlight(std::chrono::milliseconds _sync_timeout,
                   std::function<void(std::shared_ptr<const TextModeWorkingSetHighlighting> me)> _on_highlighted);

private:
    std::shared_ptr<const TextModeWorkingSet> m_WorkingSet;
    std::shared_ptr<const std::string> m_HighlightingOptions;
    std::vector<hl::Style> m_Styles;
    enum Status m_Status = Status::Inactive;
};

} // namespace nc::viewer
