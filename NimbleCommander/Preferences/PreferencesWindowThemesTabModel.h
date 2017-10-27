// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

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
@property (nonatomic, readonly) const string &entry;
@property (nonatomic, readonly) PreferencesWindowThemesTabItemType type;
- (instancetype) initWithTitle:(NSString*)title
                      forEntry:(const string&)entry
                        ofType:(PreferencesWindowThemesTabItemType)type;
@end

NSArray* BuildThemeSettingsNodesTree();
