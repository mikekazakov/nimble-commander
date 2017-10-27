// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
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
