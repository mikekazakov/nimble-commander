#pragma once

class PanelData;

class PanelDataSelection
{
public:
    PanelDataSelection(const PanelData &_pd, bool _ignore_dirs_on_mask = true);

    vector<bool> SelectionByExtension(const string &_extension,
                                      bool _result_selection = true ) const;
    vector<bool> InvertSelection() const;

private:
    const PanelData &m_Data;
    bool m_IgnoreDirectoriesOnMaskSelection;
};
