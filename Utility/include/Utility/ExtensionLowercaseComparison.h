// Copyright (C) 2015-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <unordered_map>
#include <Habanero/spinlock.h>

class ExtensionLowercaseComparison
{
public:
    static ExtensionLowercaseComparison& Instance() noexcept;
    
    /**
     * Will check if there's already a cached lowercase form of _extension.
     * If there's no - will convert to lowercase and the will compose it to FormC normalization level.
     * Will store result in cache and return.
     * Will not cache extension with utf8 length more than m_MaxLength
     */
    std::string ExtensionToLowercase(const std::string &_extension);
    std::string ExtensionToLowercase(const char *_extension);

    /**
     * Will try to find _filename_ext normalized lowercase form in cache, if can't - will produce it temporary.
     * _compare_to_formc_lc is used directly without any tranformation, so it should be normalized and lowercased already
     */
    bool Equal( const std::string &_filename_ext, const std::string &_compare_to_formc_lc );
    bool Equal( const char *_filename_ext, const std::string &_compare_to_formc_lc );

private:
    enum {                                          m_MaxLength = 16 };
    std::unordered_map<std::string, std::string>    m_Data;
    spinlock                                        m_Lock;
};
