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

    constexpr Version version =
#if   defined(__FILES_VER_LITE__)
    Version::Lite;
#elif defined(__FILES_VER_PRO__)
    Version::Pro;
#elif defined(__FILES_VER_FULL__)
    Version::Full;
#else
    #error Invalid build configuration - no version type specified
#endif

    constexpr bool is_sandboxed = (version == Version::Lite) || (version == Version::Pro);
}



#endif
