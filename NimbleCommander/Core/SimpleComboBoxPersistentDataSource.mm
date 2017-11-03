// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Core/rapidjson.h>
#include "SimpleComboBoxPersistentDataSource.h"


@implementation SimpleComboBoxPersistentDataSource
{
    vector<NSString *>  m_Items;
    int                 m_MaxItems;
    string              m_ConfigPath;
    bool                m_Clean;
}

- (instancetype)initWithStateConfigPath:(const string&)path
{
    self = [super init];
    if(self) {
        m_MaxItems = 12;
        m_ConfigPath = path;
        m_Clean = true;
  
        auto history = StateConfig().Get(m_ConfigPath);
        if( history.GetType() == rapidjson::kArrayType )
            for( auto i = history.Begin(), e = history.End(); i != e; ++i )
                if( i->GetType() == rapidjson::kStringType )
                    m_Items.emplace_back( [NSString stringWithUTF8String:i->GetString()] );
    }
    return self;
}

- (void)dealloc
{
    if( m_Clean )
        return;
    
    if( !m_ConfigPath.empty() ) {
        GenericConfig::ConfigValue arr(rapidjson::kArrayType);
        for( auto &s: m_Items )
            arr.PushBack(GenericConfig::ConfigValue(s.UTF8String, GenericConfig::g_CrtAllocator),
                         GenericConfig::g_CrtAllocator );
        StateConfig().Set(m_ConfigPath.c_str(), arr);
    }
}

- (void)reportEnteredItem:(NSString*)item
{
    if( item == nil || item.length == 0 )
        return;
    
    m_Items.erase(remove_if(begin(m_Items),
                            end(m_Items),
                            [=](auto _t) {
                                return [_t isEqualToString:item];
                            }),
                  end(m_Items)
                  );
    m_Items.insert(begin(m_Items), item);
    if((int)m_Items.size() > m_MaxItems)
        m_Items.resize(m_MaxItems);
    m_Clean = false;
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
    return m_Items.size();
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
    if(index >= 0 && index < (long)m_Items.size())
        return m_Items[index];
    return @"";
}

@end
