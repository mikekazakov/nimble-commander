//
//  SimpleComboBoxPersistentDataSource.m
//  Files
//
//  Created by Michael G. Kazakov on 15/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "SimpleComboBoxPersistentDataSource.h"

@implementation SimpleComboBoxPersistentDataSource
{
    vector<NSString *>  m_Items;
    int                 m_MaxItems;
    NSString*           m_Filename;
    bool                m_Clean;
}

- (instancetype)initWithPlistPath:(NSString*)path
{
    self = [super init];
    if(self) {
        m_MaxItems = 12;
        m_Filename = path;
        m_Clean = true;
        
        if(auto array = objc_cast<NSArray>([NSKeyedUnarchiver unarchiveObjectWithFile:m_Filename]))
            for(id obj in array)
                if(auto str = objc_cast<NSString>(obj))
                    m_Items.emplace_back(str);
    }
    return self;
}

- (void)dealloc
{
    if(!m_Clean) {
        NSMutableArray *array = [NSMutableArray arrayWithCapacity:m_Items.size()];
        for(auto i: m_Items)
            [array addObject:i];
        NSString *fn = m_Filename;
        dispatch_to_background([=]{
            [NSKeyedArchiver archiveRootObject:array toFile:fn];
        });
    }
}

- (void)reportEnteredItem:(NSString*)item
{
    if(item == nil || item.length == 0)
        return;
    
    m_Items.erase(remove_if(begin(m_Items),
                            end(m_Items),
                            [=](auto _t) {
                                return [_t isEqualToString:item];
                            }),
                  end(m_Items)
                  );
    m_Items.insert(begin(m_Items), item);
    if(m_Items.size() > m_MaxItems)
        m_Items.reserve(m_MaxItems);
    m_Clean = false;
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
    return m_Items.size();
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
    if(index >= 0 && index < m_Items.size())
        return m_Items[index];
    return @"";
}

@end