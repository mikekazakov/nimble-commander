// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DirectoryCreation.h"
#include "../AsyncDialogResponse.h"
#include "../Internal.h"
#include "DirectoryCreationJob.h"
#include <Utility/StringExtras.h>
#include <memory>
#include <ranges>

// TODO: remove once callback results are no longer wrapped into 'int'
#pragma clang diagnostic ignored "-Wold-style-cast"

namespace nc::ops {

static std::vector<std::string> Split(std::string_view _directory);

using Callbacks = DirectoryCreationJobCallbacks;

DirectoryCreation::DirectoryCreation(std::string _directory_name, std::string _root_folder, VFSHost &_vfs)
{
    m_Directories = Split(_directory_name);

    m_Job = std::make_unique<DirectoryCreationJob>(m_Directories, _root_folder, _vfs.shared_from_this());
    m_Job->m_OnError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        return static_cast<Callbacks::ErrorResolution>(OnError(_err, _path, _vfs));
    };

    const auto title = [NSString localizedStringWithFormat:NSLocalizedString(@"Creating a directory \u201c%@\u201d",
                                                                             "Creating a directory \u201c%@\u201d"),
                                                           [NSString stringWithUTF8StdString:_directory_name]];
    SetTitle(title.UTF8String);
}

DirectoryCreation::~DirectoryCreation()
{
    Wait();
}

Job *DirectoryCreation::GetJob() noexcept
{
    return m_Job.get();
}

const std::vector<std::string> &DirectoryCreation::DirectoryNames() const
{
    return m_Directories;
}

int DirectoryCreation::OnError(Error _err, const std::string &_path, VFSHost &_vfs)
{
    if( !IsInteractive() )
        return (int)Callbacks::ErrorResolution::Stop;

    const auto ctx = std::make_shared<AsyncDialogResponse>();
    ShowGenericDialog(
        GenericDialog::AbortRetry, NSLocalizedString(@"Failed to create a directory", ""), _err, {_vfs, _path}, ctx);
    WaitForDialogResponse(ctx);

    if( ctx->response == NSModalResponseRetry )
        return (int)Callbacks::ErrorResolution::Retry;
    else
        return (int)Callbacks::ErrorResolution::Stop;
}

static std::vector<std::string> Split(std::string_view _directory)
{
    std::vector<std::string> parts;
    for( const auto str : std::views::split(std::string_view{_directory}, '/') )
        if( !str.empty() )
            parts.emplace_back(std::string_view{str});
    return parts;
}

} // namespace nc::ops
