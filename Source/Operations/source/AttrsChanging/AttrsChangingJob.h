// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Job.h"
#include "Options.h"
#include <VFS/VFS.h>
#include <Base/chained_strings.h>

namespace nc::ops {

struct AttrsChangingJobCallbacks {
    enum class SourceAccessErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<SourceAccessErrorResolution(Error _err, const std::string &_path, VFSHost &_vfs)>
        m_OnSourceAccessError = [](Error, const std::string &, VFSHost &) { return SourceAccessErrorResolution::Stop; };

    enum class ChmodErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<ChmodErrorResolution(Error _err, const std::string &_path, VFSHost &_vfs)> m_OnChmodError =
        [](Error, const std::string &, VFSHost &) { return ChmodErrorResolution::Stop; };

    enum class ChownErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<ChownErrorResolution(Error _err, const std::string &_path, VFSHost &_vfs)> m_OnChownError =
        [](Error, const std::string &, VFSHost &) { return ChownErrorResolution::Stop; };

    enum class FlagsErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<FlagsErrorResolution(Error _err, const std::string &_path, VFSHost &_vfs)> m_OnFlagsError =
        [](Error, const std::string &, VFSHost &) { return FlagsErrorResolution::Stop; };

    enum class TimesErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<TimesErrorResolution(Error _err, const std::string &_path, VFSHost &_vfs)> m_OnTimesError =
        [](Error, const std::string &, VFSHost &) { return TimesErrorResolution::Stop; };
};

class AttrsChangingJob : public Job, public AttrsChangingJobCallbacks
{
public:
    AttrsChangingJob(AttrsChangingCommand _command);
    ~AttrsChangingJob();

private:
    virtual void Perform() override;
    void DoScan();
    void ScanItem(unsigned _origin_item);
    void ScanItem(const std::string &_full_path,
                  const std::string &_filename,
                  unsigned _origin_item,
                  const base::chained_strings::node *_prefix);
    void DoChange();
    bool AlterSingleItem(const std::string &_path, VFSHost &_vfs, const VFSStat &_stat);
    bool ChmodSingleItem(const std::string &_path, VFSHost &_vfs, const VFSStat &_stat);
    bool ChownSingleItem(const std::string &_path, VFSHost &_vfs, const VFSStat &_stat);
    bool ChflagSingleItem(const std::string &_path, VFSHost &_vfs, const VFSStat &_stat);
    bool ChtimesSingleItem(const std::string &_path, VFSHost &_vfs, const VFSStat &_stat);

    struct Meta;
    const AttrsChangingCommand m_Command;
    std::optional<std::pair<uint16_t, uint16_t>> m_ChmodCommand;
    std::optional<std::pair<uint32_t, uint32_t>> m_ChflagCommand;
    base::chained_strings m_Filenames;
    std::vector<Meta> m_Metas;
};

} // namespace nc::ops
