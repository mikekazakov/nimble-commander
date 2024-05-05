// Copyright (C) 2017-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <vector>
#include <string>
#include <Utility/FileMask.h>

namespace nc::panel::data {

class Model;

class SelectionBuilder
{
public:
    SelectionBuilder(const nc::panel::data::Model &_pd, bool _ignore_dirs_on_mask = true);

    // it would be good to transform these methods into something like this:
    // pair<vector<unsigned>,vector<bool>> to reduce redundant operations.

    std::vector<bool> SelectionByExtension(const std::string &_extension, bool _result_selection = true) const;
    std::vector<bool> SelectionByMask(const utility::FileMask &_mask, bool _result_selection = true) const;

    std::vector<bool> InvertSelection() const;

private:
    const nc::panel::data::Model &m_Data;
    bool m_IgnoreDirectoriesOnMaskSelection;
};

}; // namespace nc::panel::data
