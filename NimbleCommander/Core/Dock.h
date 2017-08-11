#pragma once

namespace nc::core {

class Dock
{
public:
    Dock();
    ~Dock();
    
    double Progress() const noexcept;
    void SetProgress(double _value);
    
private:
    Dock(const Dock&) = delete;
    void operator=(const Dock&) = delete;
    
    double              m_Progress;
    NSDockTile          *m_Tile;
    NSProgressIndicator *m_Indicator;
};

}
