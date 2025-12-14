// Copyright (C) 2019-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <string_view>

namespace nc::utility {

class UTIDB
{
public:
    virtual ~UTIDB() = 0;

    // Provides an Universal Type Identifier (UTI) for the specified file extension.
    // Always succeeds, returning a dynamic UTI if the extension is unknown.
    virtual std::string UTIForExtension(std::string_view _extension) const = 0;

    // Returns true if the specified UTI is a registered in the system, i.e. is permananent/known.
    virtual bool IsDeclaredUTI(std::string_view _uti) const = 0;

    // Returns true if the specified UTI is dynamic, i.e. ephemeral and generated on-the-fly.
    virtual bool IsDynamicUTI(std::string_view _uti) const = 0;

    // Returns true if the specified UTI conforms to another UTI, e.g.
    // "public.jpeg" conforms to "public.image".
    virtual bool ConformsTo(std::string_view _uti, std::string_view _conforms_to) const = 0;
};

} // namespace nc::utility
