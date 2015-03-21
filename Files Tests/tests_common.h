//
//  tests_common.h
//  Files
//
//  Created by Michael G. Kazakov on 26.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <XCTest/XCTest.h>

#define _XCTAssertCPPThrows(test, expression, expressionStr, format...) \
    ({ \
        bool __caughtException = false; \
        try { \
            (expression); \
        } \
        catch (...) { \
            __caughtException = true; \
        }\
        if (!__caughtException) { \
            _XCTRegisterFailure(test, _XCTFailureDescription(_XCTAssertion_Throws, 0, expressionStr), format); \
    } \
})

#define XCTAssertCPPThrows(expression, format...) \
    _XCTAssertCPPThrows(self, expression, @#expression, format)

static const path g_DataPref = "/.FilesTestingData";
