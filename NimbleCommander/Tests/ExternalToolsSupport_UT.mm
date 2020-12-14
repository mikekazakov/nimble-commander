// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include <NimbleCommander/States/FilePanels/ExternalToolsSupport.h>
#include <iostream>

TEST_CASE("ExternalToolsSupport parsing")
{
    ExternalToolsParametersParser p;
    auto unexpected_error_callback = [=](std::string e) {
        std::cout << e << std::endl;
        CHECK( false );
    };
    
    {
        auto parameters = p.Parse("Hello Word!", unexpected_error_callback);
        CHECK( parameters.StepsAmount() == 1 );
        CHECK( parameters.StepNo(0).type == ExternalToolsParameters::ActionType::UserDefined );
        CHECK( parameters.GetUserDefined(parameters.StepNo(0).index).text == "Hello Word!" );
    }

    {
        auto parameters = p.Parse("%-%-Hello Word!%-777LP", unexpected_error_callback);
        CHECK( parameters.StepsAmount() == 2 );
        CHECK( parameters.StepNo(1).type == ExternalToolsParameters::ActionType::SelectedItems );
        CHECK( parameters.GetSelectedItems(parameters.StepNo(1).index).max == 777 );
        CHECK( parameters.GetSelectedItems(parameters.StepNo(1).index).as_parameters == false );
        CHECK( parameters.GetSelectedItems(parameters.StepNo(1).index).what == ExternalToolsParameters::FileInfo::Path );
        CHECK( parameters.GetSelectedItems(parameters.StepNo(1).index).location == ExternalToolsParameters::Location::Target );
    }

    {
        auto parameters = p.Parse("%-%-Hello Word!%-777LP%-%50F", unexpected_error_callback);
        CHECK( parameters.StepsAmount() == 3 );
        
        CHECK( parameters.StepNo(1).type == ExternalToolsParameters::ActionType::SelectedItems );
        CHECK( parameters.GetSelectedItems(parameters.StepNo(1).index).max == 777 );
        CHECK( parameters.GetSelectedItems(parameters.StepNo(1).index).as_parameters == false );
        CHECK( parameters.GetSelectedItems(parameters.StepNo(1).index).what == ExternalToolsParameters::FileInfo::Path );
        CHECK( parameters.GetSelectedItems(parameters.StepNo(1).index).location == ExternalToolsParameters::Location::Target );
        
        CHECK( parameters.StepNo(2).type == ExternalToolsParameters::ActionType::SelectedItems );
        CHECK( parameters.GetSelectedItems(parameters.StepNo(2).index).max == 50 );
        CHECK( parameters.GetSelectedItems(parameters.StepNo(2).index).as_parameters == true );
        CHECK( parameters.GetSelectedItems(parameters.StepNo(2).index).what == ExternalToolsParameters::FileInfo::Filename );
        CHECK( parameters.GetSelectedItems(parameters.StepNo(2).index).location == ExternalToolsParameters::Location::Left );
    }
    
    {
        auto parameters = p.Parse("%f%%%\"???\"?", unexpected_error_callback);
        CHECK( parameters.StepsAmount() == 3 );
        CHECK( parameters.StepNo(0).type == ExternalToolsParameters::ActionType::CurrentItem );
        CHECK( parameters.GetCurrentItem(parameters.StepNo(0).index).what == ExternalToolsParameters::FileInfo::Filename );
        CHECK( parameters.GetCurrentItem(parameters.StepNo(0).index).location == ExternalToolsParameters::Location::Source );
        
        CHECK( parameters.StepNo(1).type == ExternalToolsParameters::ActionType::UserDefined );
        CHECK( parameters.GetUserDefined(parameters.StepNo(1).index).text == "%" );
        
        CHECK( parameters.StepNo(2).type == ExternalToolsParameters::ActionType::EnterValue );
        CHECK( parameters.GetEnterValue(parameters.StepNo(2).index).name == "???" );
    }
}
