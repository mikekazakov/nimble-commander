//
//  MassRename_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 29/04/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "tests_common.h"

#include "MassRename.h"

@interface MassRename_Tests : XCTestCase

@end

@implementation MassRename_Tests


- (void)testReplace_Fullname
{
    MassRename::FileInfo dummy;
    MassRename::Action replace = MassRename::ReplaceText("abra",
                                                         "alakazam",
                                                         MassRename::ApplyTo::FullName,
                                                         MassRename::ReplaceText::ReplaceMode::EveryOccurrence,
                                                         false);
    optional<string> res;
    
    res = replace.Apply("iahusidhaabra12313", dummy);
    XCTAssert( res && res.value() == "iahusidhaalakazam12313" );
    
    res = replace.Apply("Abra!abrA", dummy);
    XCTAssert( res && res.value() == "alakazam!alakazam" );
}

- (void)testReplace_Filename_Every
{
    MassRename::FileInfo dummy;
    MassRename::Action replace = MassRename::ReplaceText("ё",
                                                         "Й",
                                                         MassRename::ApplyTo::Name,
                                                         MassRename::ReplaceText::ReplaceMode::EveryOccurrence,
                                                         false);
    
    optional<string> res;
    res = replace.Apply(@"ееёЁё.ё".fileSystemRepresentation, dummy);
    XCTAssert( res && res.value() == @"ееЙЙЙ.ё".fileSystemRepresentation );
    
    res = replace.Apply(@"ёё".fileSystemRepresentation, dummy);
    XCTAssert( res && res.value() == @"ЙЙ".fileSystemRepresentation );

    res = replace.Apply(@"ёё.".fileSystemRepresentation, dummy);
    XCTAssert( res && res.value() == @"ЙЙ.".fileSystemRepresentation );

    res = replace.Apply(@".ёё".fileSystemRepresentation, dummy);
    XCTAssert( res && res.value() == @".ЙЙ".fileSystemRepresentation );
    
    res = replace.Apply("", dummy);
    XCTAssert( !res );
    
    res = replace.Apply(".", dummy);
    XCTAssert( !res );
}

- (void)testReplace_Filename_First
{
    MassRename::FileInfo dummy;
    MassRename::Action replace = MassRename::ReplaceText("A",
                                                         "B",
                                                         MassRename::ApplyTo::Name,
                                                         MassRename::ReplaceText::ReplaceMode::FirstOccurrence,
                                                         false);
    optional<string> res;
    res = replace.Apply("qwAab.a", dummy);
    XCTAssert( res && res.value() == "qwBab.a" );
    
    res = replace.Apply("Aa", dummy);
    XCTAssert( res && res.value() == "Ba" );
    
    res = replace.Apply("bA.", dummy);
    XCTAssert( res && res.value() == "bB." );
    
    res = replace.Apply(".ba", dummy);
    XCTAssert( res && res.value() == ".bB" );
    
    res = replace.Apply("", dummy);
    XCTAssert( !res );
    
    res = replace.Apply(".", dummy);
    XCTAssert( !res );
}

- (void)testReplace_Filename_Last
{
    MassRename::FileInfo dummy;
    MassRename::Action replace = MassRename::ReplaceText("A",
                                                         "B",
                                                         MassRename::ApplyTo::Name,
                                                         MassRename::ReplaceText::ReplaceMode::LastOccurrence,
                                                         false);
    
    optional<string> res;
    res = replace.Apply("qwAab.a", dummy);
    XCTAssert( res && res.value() == "qwABb.a" );
    
    res = replace.Apply("Aa", dummy);
    XCTAssert( res && res.value() == "AB" );
    
    res = replace.Apply("bA.", dummy);
    XCTAssert( res && res.value() == "bB." );
    
    res = replace.Apply(".ba", dummy);
    XCTAssert( res && res.value() == ".bB" );
    
    res = replace.Apply("", dummy);
    XCTAssert( !res );
    
    res = replace.Apply(".", dummy);
    XCTAssert( !res );
}

- (void)testReplace_Ext_Every
{
    MassRename::FileInfo dummy;
    MassRename::Action replace = MassRename::ReplaceText("jpg",
                                                         "png",
                                                         MassRename::ApplyTo::Extension,
                                                         MassRename::ReplaceText::ReplaceMode::EveryOccurrence,
                                                         false);
    optional<string> res;
    res = replace.Apply("1.jpg", dummy);
    XCTAssert( res && res.value() == "1.png" );

    res = replace.Apply("1.jpgjpg", dummy);
    XCTAssert( res && res.value() == "1.pngpng" );

    res = replace.Apply("1.JPGjpg", dummy);
    XCTAssert( res && res.value() == "1.pngpng" );
    
    res = replace.Apply("jpg.jpg", dummy);
    XCTAssert( res && res.value() == "jpg.png" );

    res = replace.Apply(".jpg", dummy);
    XCTAssert( !res );
}

- (void)testReplace_Ext_First
{
    MassRename::FileInfo dummy;
    MassRename::Action replace = MassRename::ReplaceText("jpg",
                                                         "png",
                                                         MassRename::ApplyTo::Extension,
                                                         MassRename::ReplaceText::ReplaceMode::FirstOccurrence,
                                                         false);
    optional<string> res;
    res = replace.Apply("1.jpg", dummy);
    XCTAssert( res && res.value() == "1.png" );
    
    res = replace.Apply("1.jpgjpg", dummy);
    XCTAssert( res && res.value() == "1.pngjpg" );
    
    res = replace.Apply("1.JPGjpg", dummy);
    XCTAssert( res && res.value() == "1.pngjpg" );
    
    res = replace.Apply("jpg.jpg", dummy);
    XCTAssert( res && res.value() == "jpg.png" );
    
    res = replace.Apply(".jpg", dummy);
    XCTAssert( !res );
}

- (void)testReplace_ExtWD_Last
{
    MassRename::FileInfo dummy;
    MassRename::Action replace = MassRename::ReplaceText(".jpg",
                                                         "_",
                                                         MassRename::ApplyTo::ExtensionWithDot,
                                                         MassRename::ReplaceText::ReplaceMode::LastOccurrence,
                                                         false);
    optional<string> res;
    res = replace.Apply("1.jpg", dummy);
    XCTAssert( res && res.value() == "1_" );
    
    res = replace.Apply("1.jpgjpg", dummy);
    XCTAssert( res && res.value() == "1_jpg" );
    
    res = replace.Apply("1.JPGjpg", dummy);
    XCTAssert( res && res.value() == "1_jpg" );
    
    res = replace.Apply("jpg.jpg", dummy);
    XCTAssert( res && res.value() == "jpg_" );
    
    res = replace.Apply(".jpg", dummy);
    XCTAssert( !res );
}

- (void)testAddText
{
    MassRename::FileInfo dummy;
    optional<string> res;
    
    MassRename::Action a1 = MassRename::AddText("$", MassRename::ApplyTo::FullName, MassRename::Position::Beginning);
    res = a1.Apply("1.jpg", dummy);
    XCTAssert( res && res.value() == "$1.jpg" );

    res = a1.Apply("1", dummy);
    XCTAssert( res && res.value() == "$1" );

    res = a1.Apply("", dummy);
    XCTAssert( res && res.value() == "$" );
    
    MassRename::Action a2 = MassRename::AddText("$", MassRename::ApplyTo::FullName, MassRename::Position::Ending);
    res = a2.Apply("1.jpg", dummy);
    XCTAssert( res && res.value() == "1.jpg$" );
    
    res = a2.Apply("1", dummy);
    XCTAssert( res && res.value() == "1$" );
    
    res = a2.Apply("", dummy);
    XCTAssert( res && res.value() == "$" );

    MassRename::Action a3 = MassRename::AddText("$", MassRename::ApplyTo::Name, MassRename::Position::Ending);
    res = a3.Apply("1.jpg", dummy);
    XCTAssert( res && res.value() == "1$.jpg" );
    
    res = a3.Apply("1", dummy);
    XCTAssert( res && res.value() == "1$" );
    
    res = a3.Apply("", dummy);
    XCTAssert( res && res.value() == "$" );

    MassRename::Action a4 = MassRename::AddText("$", MassRename::ApplyTo::Extension, MassRename::Position::Beginning);
    res = a4.Apply("1.jpg", dummy);
    XCTAssert( res && res.value() == "1.$jpg" );

    res = a4.Apply("1.jpg.", dummy);
    XCTAssert( res && res.value() == "1.jpg.$" );
    
    res = a4.Apply("1", dummy);
    XCTAssert( !res );
    
    res = a4.Apply("", dummy);
    XCTAssert( !res );

    MassRename::Action a5 = MassRename::AddText("$", MassRename::ApplyTo::ExtensionWithDot, MassRename::Position::Beginning);
    res = a5.Apply("1.jpg", dummy);
    XCTAssert( res && res.value() == "1$.jpg" );
    
    res = a5.Apply("1.jpg.", dummy);
    XCTAssert( res && res.value() == "1.jpg$." );
    
    res = a5.Apply("1", dummy);
    XCTAssert( !res );
    
    res = a5.Apply("", dummy);
    XCTAssert( !res );
    
    MassRename::Action a6 = MassRename::AddText("$", MassRename::ApplyTo::ExtensionWithDot, MassRename::Position::Ending);
    res = a6.Apply("1.jpg", dummy);
    XCTAssert( res && res.value() == "1.jpg$" );
    
    res = a6.Apply("1.jpg.", dummy);
    XCTAssert( res && res.value() == "1.jpg.$" );
    
    res = a6.Apply("1", dummy);
    XCTAssert( !res );
    
    res = a6.Apply("", dummy);
    XCTAssert( !res );
    
    res = a6.Apply("...", dummy);
    XCTAssert( res && res.value() == "...$" );
}

@end
