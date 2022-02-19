// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ExternalTools.h"
#include "Tests.h"

#define PREFIX "ExternalTools "

using namespace nc;
using namespace nc::panel;

using Params = ExternalToolsParameters;
using Step = ExternalToolsParameters::Step;
using Location = ExternalToolsParameters::Location;
using SelectedItems = ExternalToolsParameters::SelectedItems;
using FI = ExternalToolsParameters::FileInfo;

static void NoError(std::string err)
{
    INFO(err);
    REQUIRE(false);
}

TEST_CASE(PREFIX "Parsing empty produces no parameters")
{
    const auto params = ExternalToolsParametersParser{}.Parse("", NoError);
    CHECK(params.StepsAmount() == 0);
    CHECK(params.Steps().empty());
}

TEST_CASE(PREFIX "Parsing - errors")
{
    const char *invalids[] = {
        "%",   // non-terminated percent command
        "%\"", // non-terminated enter value
        "%\"?" // enter value with broken quotes
    };
    for( auto invalid : invalids ) {
        bool failed = false;
        auto error = [&failed](std::string) { failed = true; };
        ExternalToolsParametersParser{}.Parse(invalid, error);
        INFO(invalid);
        CHECK(failed);
    }
}

TEST_CASE(PREFIX "Parsing - text")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("blah", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::UserDefined, 0});
        REQUIRE(p.GetUserDefined(0).text == "blah");
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("foo blah !", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::UserDefined, 0});
        REQUIRE(p.GetUserDefined(0).text == "foo blah !");
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%%", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::UserDefined, 0});
        REQUIRE(p.GetUserDefined(0).text == "%");
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("foo%%bar", NoError);
        REQUIRE(p.StepsAmount() == 3);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::UserDefined, 0});
        REQUIRE(p.GetUserDefined(0).text == "foo");
        REQUIRE(p.Steps()[1] == Step{Params::ActionType::UserDefined, 1});
        REQUIRE(p.GetUserDefined(1).text == "%");
        REQUIRE(p.Steps()[2] == Step{Params::ActionType::UserDefined, 2});
        REQUIRE(p.GetUserDefined(2).text == "bar");
    }
}

TEST_CASE(PREFIX "Parsing - dialog value")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%?", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::EnterValue, 0});
        REQUIRE(p.GetEnterValue(0).name == "");
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%\"hello\"?", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::EnterValue, 0});
        REQUIRE(p.GetEnterValue(0).name == "hello");
    }
}

TEST_CASE(PREFIX "Parsing - directory path")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%r", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::DirectoryPath);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-r", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::DirectoryPath);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-%r", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::DirectoryPath);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-%-r", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::DirectoryPath);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - current path")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%p", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Path);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-p", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Path);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-%p", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Path);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-%-p", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Path);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - filename")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%f", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Filename);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-f", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Filename);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-%f", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Filename);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-%-f", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::Filename);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - filename without extension")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%n", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FilenameWithoutExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-n", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FilenameWithoutExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-%n", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FilenameWithoutExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-%-n", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FilenameWithoutExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - filename extension")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%e", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FileExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Source);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-e", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FileExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Target);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-%e", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FileExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Left);
    }
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%-%-e", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::CurrentItem, 0});
        REQUIRE(p.GetCurrentItem(0).what == FI::FileExtension);
        REQUIRE(p.GetCurrentItem(0).location == Location::Right);
    }
}

TEST_CASE(PREFIX "Parsing - selected filenames")
{
    {
        const auto p = ExternalToolsParametersParser{}.Parse("%F", NoError);
        REQUIRE(p.StepsAmount() == 1);
        REQUIRE(p.Steps()[0] == Step{Params::ActionType::SelectedItems, 0});
        REQUIRE(p.GetSelectedItems(0) ==
                SelectedItems{Location::Source, FI::Filename, 0, true});
    }
}

//- produces % symbol:  %%                           ok
//- dialog value: %?, %"some text"?                  ok
//- directory path: %r, %-r                          ok
//- current path: %p, %-p                            ok
//- filename: %f, %-f                                ok
//- filename without extension: %n, %-n              ok
//- file extension: %e, %-e                          ok

//- selected filenames as parameters: %F, %-F, %10F, %-10F

//- selected filepaths as parameters: %P, %-P, %10P, %-10P
//- list of selected files:
//  - filenames: %LF, %-LF, %L10F, %-L50F
//  - filepaths: %LP, %-LP, %L50P, %-L50P
//- toggle left/right instead of source/target and vice versa: %-
//- limit maxium total amount of files output %2T, %15T
