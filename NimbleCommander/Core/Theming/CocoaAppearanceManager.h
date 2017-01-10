#pragma once

class CocoaAppearanceManager
{
public:
    static CocoaAppearanceManager& Instance();
    
    void ManageWindowApperance( NSWindow *_window );


private:
    // ....
    

};
