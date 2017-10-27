// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include "ExternalToolsSupport.h"

@interface ExternalToolsSupport_Tests : XCTestCase

@end


@implementation ExternalToolsSupport_Tests

- (void)testParsing
{
    ExternalToolsParametersParser p;
    auto unexpected_error_callback = [=](string e) {
        cout << e << endl;
        XCTAssert( false );
    };
    
    {
        auto parameters = p.Parse("Hello Word!", unexpected_error_callback);
        XCTAssert( parameters.StepsAmount() == 1 );
        XCTAssert( parameters.StepNo(0).type == ExternalToolsParameters::ActionType::UserDefined );
        XCTAssert( parameters.GetUserDefined(parameters.StepNo(0).index).text == "Hello Word!" );
    }

    {
        auto parameters = p.Parse("%-%-Hello Word!%-777LP", unexpected_error_callback);
        XCTAssert( parameters.StepsAmount() == 2 );
        XCTAssert( parameters.StepNo(1).type == ExternalToolsParameters::ActionType::SelectedItems );
        XCTAssert( parameters.GetSelectedItems(parameters.StepNo(1).index).max == 777 );
        XCTAssert( parameters.GetSelectedItems(parameters.StepNo(1).index).as_parameters == false );
        XCTAssert( parameters.GetSelectedItems(parameters.StepNo(1).index).what == ExternalToolsParameters::FileInfo::Path );
        XCTAssert( parameters.GetSelectedItems(parameters.StepNo(1).index).location == ExternalToolsParameters::Location::Target );
    }

    {
        auto parameters = p.Parse("%-%-Hello Word!%-777LP%-%50F", unexpected_error_callback);
        XCTAssert( parameters.StepsAmount() == 3 );
        
        XCTAssert( parameters.StepNo(1).type == ExternalToolsParameters::ActionType::SelectedItems );
        XCTAssert( parameters.GetSelectedItems(parameters.StepNo(1).index).max == 777 );
        XCTAssert( parameters.GetSelectedItems(parameters.StepNo(1).index).as_parameters == false );
        XCTAssert( parameters.GetSelectedItems(parameters.StepNo(1).index).what == ExternalToolsParameters::FileInfo::Path );
        XCTAssert( parameters.GetSelectedItems(parameters.StepNo(1).index).location == ExternalToolsParameters::Location::Target );
        
        XCTAssert( parameters.StepNo(2).type == ExternalToolsParameters::ActionType::SelectedItems );
        XCTAssert( parameters.GetSelectedItems(parameters.StepNo(2).index).max == 50 );
        XCTAssert( parameters.GetSelectedItems(parameters.StepNo(2).index).as_parameters == true );
        XCTAssert( parameters.GetSelectedItems(parameters.StepNo(2).index).what == ExternalToolsParameters::FileInfo::Filename );
        XCTAssert( parameters.GetSelectedItems(parameters.StepNo(2).index).location == ExternalToolsParameters::Location::Left );
    }
    
    {
        auto parameters = p.Parse("%f%%%\"???\"?", unexpected_error_callback);
        XCTAssert( parameters.StepsAmount() == 3 );
        XCTAssert( parameters.StepNo(0).type == ExternalToolsParameters::ActionType::CurrentItem );
        XCTAssert( parameters.GetCurrentItem(parameters.StepNo(0).index).what == ExternalToolsParameters::FileInfo::Filename );
        XCTAssert( parameters.GetCurrentItem(parameters.StepNo(0).index).location == ExternalToolsParameters::Location::Source );
        
        XCTAssert( parameters.StepNo(1).type == ExternalToolsParameters::ActionType::UserDefined );
        XCTAssert( parameters.GetUserDefined(parameters.StepNo(1).index).text == "%" );
        
        XCTAssert( parameters.StepNo(2).type == ExternalToolsParameters::ActionType::EnterValue );
        XCTAssert( parameters.GetEnterValue(parameters.StepNo(2).index).name == "???" );
    }
}



@end
