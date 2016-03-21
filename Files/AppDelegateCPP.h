#pragma once

class AppDelegateCPP
{
public:
    static const string &StartupCWD();
    static const string &ConfigDirectory();
    static const string &StateDirectory();
    static const string &SupportDirectory();
    
};

//*/
//@property (nonatomic, readonly) const string& startupCWD;
//
///**
// * By default this dir is ~/Library/Application Support/Files(Lite,Pro).
// * May change in the future.
// */
//@property (nonatomic, readonly) const string& configDirectory;
//
///**
// * This dir is ~/Library/Application Support/Files(Lite,Pro)/State/.
// */
//@property (nonatomic, readonly) const string& stateDirectory;