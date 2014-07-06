//
//  Configuration.h
//  Files
//
//  Created by Michael G. Kazakov on 04/07/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#ifdef __cplusplus

namespace configuration
{
    enum class Version
    {
        /**
         * Sandboxed version with reduced functionality.
         * Presumably free on MacAppStore, may be with in-app purchases in the future.
         */
        Lite,

        /**
         * Sandboxed version with as maximum functionality, as sandboxing model permits.
         * Presumably exists as paid version on MacAppStore.
         */
        Pro,
        
        /**
         * Non-sandboxed version with whole functionality available.
         */
        Full
    };

#if   defined(__FILES_VER_LITE__)
    constexpr Version version = Version::Lite;
    #define __FILES_IDENTIFIER__ "info.filesmanager.Files-Lite"
#elif defined(__FILES_VER_PRO__)
    constexpr Version version = Version::Pro;
    #define __FILES_IDENTIFIER__ "info.filesmanager.Files-Pro"
#elif defined(__FILES_VER_FULL__)
    constexpr Version version = Version::Full;
    #define __FILES_IDENTIFIER__ "info.filesmanager.Files"
#else
    #error Invalid build configuration - no version type specified
#endif
    
    constexpr const char *identifier = __FILES_IDENTIFIER__;
    constexpr bool is_sandboxed = (version == Version::Lite) || (version == Version::Pro);
}



#endif
