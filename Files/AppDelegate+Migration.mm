#include "Common.h"
#include "Config.h"
#include "AppDelegate+Migration.h"


@implementation AppDelegate (Migration)

- (void) migrateUserDefaultsToJSONConfig_1_1_0_to_1_1_1
{
    auto move_bool = [](NSString *_default, const char *_config) {
        if( auto v = objc_cast<NSNumber>([NSUserDefaults.standardUserDefaults objectForKey:_default]) )
        GlobalConfig().Set(_config, (bool)v.boolValue);
        [NSUserDefaults.standardUserDefaults removeObjectForKey:_default];
    };
    auto move_int = [](NSString *_default, const char *_config) {
        if( auto v = objc_cast<NSNumber>([NSUserDefaults.standardUserDefaults objectForKey:_default]) )
        GlobalConfig().Set(_config, v.intValue);
        [NSUserDefaults.standardUserDefaults removeObjectForKey:_default];
    };
    auto move_string = [](NSString *_default, const char *_config) {
        if( auto v = objc_cast<NSString>([NSUserDefaults.standardUserDefaults objectForKey:_default]) )
        GlobalConfig().Set(_config, v.UTF8String);
        [NSUserDefaults.standardUserDefaults removeObjectForKey:_default];
    };
    move_int (@"skin",                                                      "general.skin");
    move_bool(@"FilePanelsGeneralShowDotDotEntry",                          "filePanel.general.showDotDotEntry");
    move_bool(@"FilePanelsGeneralIgnoreDirectoriesOnSelectionWithMask",     "filePanel.general.ignoreDirectoriesOnSelectionWithMask");
    move_bool(@"FilePanelsGeneralUseTildeAsHomeShotcut",                    "filePanel.general.useTildeAsHomeShortcut");
    move_bool(@"FilePanelsGeneralAppendOtherWindowsPathsToGoToMenu",        "filePanel.general.appendOtherWindowsPathsToGoToMenu");
    move_bool(@"FilePanelsGeneralGoToShowConnections",                      "filePanel.general.showNetworkConnectionsInGoToMenu");
    move_int (@"FilePanelsGeneralGoToConnectionsLimit",                     "filePanel.general.maximumNetworkConnectionsInGoToMenu");
    move_bool(@"FilePanelsGeneralShowVolumeInformationBar",                 "filePanel.general.showVolumeInformationBar");
    move_bool(@"FilePanelsGeneralShowLocalizedFilenames",                   "filePanel.general.showLocalizedFilenames");
    move_bool(@"FilePanelsGeneralAllowDraggingIntoFolders",                 "filePanel.general.allowDraggingIntoFolders");
    move_bool(@"FilePanelsGeneralGoToForceActivation",                      "filePanel.general.goToButtonForcesPanelActivation");
    move_int (@"FilePanelsGeneralFileSizeFormat",                           "filePanel.general.fileSizeFormat");
    move_int (@"FilePanelsGeneralSelectionSizeFormat",                      "filePanel.general.selectionSizeFormat");
    move_bool(@"FilePanelsGeneralRouteKeyboardInputIntoTerminal",           "filePanel.general.routeKeyboardInputIntoTerminal");
    move_string(@"FilePanelsChecksumCalculationAlgorithm",                  "filePanel.general.checksumCalculationAlgorithm");
    move_int (@"FilePanelsQuickSearchWhereToFind",                          "filePanel.quickSearch.whereToFind");
    move_bool(@"FilePanelsQuickSearchSoftFiltering",                        "filePanel.quickSearch.softFiltering");
    move_bool(@"FilePanelsQuickSearchTypingView",                           "filePanel.quickSearch.typingView");
    move_int (@"FilePanelsQuickSearchKeyModifier",                          "filePanel.quickSearch.keyOption");
    move_int (@"FilePanels_Modern_FontSize",                                "filePanel.modern.fontSize");
    move_int (@"FilePanelsModernIconsMode",                                 "filePanel.modern.iconsMode");
    move_bool(@"GeneralShowToolbar",                                        "general.showToolbar");
    move_bool(@"GeneralShowTabs",                                           "general.showTabs");
    move_bool(@"Terminal_HideScrollbar",                                    "terminal.hideVerticalScrollbar");
    move_bool(@"BigFileViewDoSaveFileEncoding",                             "viewer.saveFileEncoding");
    move_bool(@"BigFileViewDoSaveFileMode",                                 "viewer.saveFileMode");
    move_bool(@"BigFileViewDoSaveFilePosition",                             "viewer.saveFilePosition");
    move_bool(@"BigFileViewDoSaveFileWrapping",                             "viewer.saveFileWrapping");
    move_bool(@"BigFileViewDoSaveFileSelection",                            "viewer.saveFileSelection");
    move_bool(@"BigFileViewRespectComAppleTextEncoding",                    "viewer.respectComAppleTextEncoding");
    move_bool(@"BigFileViewCaseSensitiveSearch",                            "viewer.searchCaseSensitive");
    move_bool(@"BigFileViewWholePhraseSearch",                              "viewer.searchForWholePhrase");
    move_bool(@"BigFileViewEncodingAutoDetect",                             "viewer.autoDetectEncoding");
    move_int (@"BigFileViewFileWindowPow2X",                                "viewer.fileWindowSize");
    move_string(@"BigFileViewDefaultEncoding",                              "viewer.defaultEncoding");
    move_bool(@"BigFileViewModernShouldAntialias",                          "viewer.modern.shouldAntialiasText");
    move_bool(@"BigFileViewModernShouldSmoothFonts",                        "viewer.modern.shouldSmoothText");
    move_bool(@"BigFileViewClassicShouldAntialias",                         "viewer.classic.shouldAntialiasText");
    move_bool(@"BigFileViewClassicShouldSmoothFonts",                       "viewer.classic.shouldSmoothText");
}

@end

