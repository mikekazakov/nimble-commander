// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <string>

enum class PreferencesWindowThemesTabItemType
{
    Color,
    Font,
    ColoringRules,
    Appearance,
    ThemeTitle
    // bool?
};

@interface PreferencesWindowThemesTabGroupNode : NSObject
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSArray *children;
- (instancetype) initWithTitle:(NSString*)title
                   andChildren:(NSArray*)children;
@end


@interface PreferencesWindowThemesTabItemNode : NSObject
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) const std::string &entry;
@property (nonatomic, readonly) PreferencesWindowThemesTabItemType type;
- (instancetype) initWithTitle:(NSString*)title
                      forEntry:(const std::string&)entry
                        ofType:(PreferencesWindowThemesTabItemType)type;
@end

NSArray* BuildThemeSettingsNodesTree();
