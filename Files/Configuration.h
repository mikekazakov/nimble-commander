//
//  Configuration.h
//  Files
//
//  Created by Michael G. Kazakov on 04/07/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#ifdef __cplusplus

#if   defined(__FILES_VER_LITE__)
    #define __FILES_VERSION_NUMBER__ ::configuration::Version::Lite
    #define __FILES_IDENTIFIER__ "info.filesmanager.Files-Lite"
#elif defined(__FILES_VER_PRO__)
    #define __FILES_VERSION_NUMBER__ ::configuration::Version::Pro
    #define __FILES_IDENTIFIER__ "info.filesmanager.Files-Pro"
#elif defined(__FILES_VER_FULL__)
    #define __FILES_VERSION_NUMBER__ ::configuration::Version::Full
    #define __FILES_IDENTIFIER__ "info.filesmanager.Files"
#else
    #error Invalid build configuration - no version type specified
#endif

namespace configuration
{
    enum class Version
    {
        /**
         * Sandboxed version with reduced functionality.
         * Presumably free on MacAppStore, may be with in-app purchases in the future.
         */
        Lite = 0,

        /**
         * Sandboxed version with as maximum functionality, as sandboxing model permits.
         * Presumably exists as paid version on MacAppStore.
         */
        Pro = 1,
        
        /**
         * Non-sandboxed version with whole functionality available.
         */
        Full = 2
    };
    
    constexpr Version version                       = __FILES_VERSION_NUMBER__;
    constexpr const char *identifier                = __FILES_IDENTIFIER__;
    constexpr bool is_sandboxed                     = version <= Version::Pro;
    constexpr bool has_psfs                         = version >= Version::Pro;
    constexpr bool has_terminal                     = version == Version::Full;
    constexpr bool has_brief_system_overview        = version >= Version::Pro;
    constexpr bool has_unix_attributes_editing      = version >= Version::Pro;
    constexpr bool has_detailed_volume_information  = version >= Version::Pro;
    constexpr bool has_internal_viewer              = version >= Version::Pro;
    constexpr bool has_compression_operation        = version >= Version::Pro;
    constexpr bool has_archives_browsing            = version >= Version::Pro;
}
#endif
