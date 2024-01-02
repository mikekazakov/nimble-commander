// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <functional>
#include <optional>

namespace nc::utility
{

/**
 * The difference between BriefOnDiskStorage and TemporaryFileStorage is that the latter
 * doesn't control life of entries precisely.
 * BriefOnDiskStorage cleans files immediately in RAII-style, while TemporaryFileStorage
 * uses a cleanup strategy based on timestamps.
 */
class BriefOnDiskStorage
{
public:    
    virtual ~BriefOnDiskStorage() = default;

    class PlacementResult;    
    
    /**
     * Writes _bytes of _data to a temporary file with an unspecified name and path.
     * The temporary file will be erased when PlacementResult object is destroyed. 
     */
    virtual std::optional<PlacementResult> Place(const void *_data,
                                                 long _bytes) = 0;
    
    /**
     * Writes _bytes of _data to a temporary file with an unspecified name and path, but with a
     * guarantee that filename of a temporary file will end with "._extension".
     * The temporary file will be erased when PlacementResult object is destroyed.
     */
    virtual std::optional<PlacementResult> PlaceWithExtension(const void *_data,
                                                              long _bytes,
                                                              const std::string& _extension) = 0;    
};

class BriefOnDiskStorage::PlacementResult {
public:
    PlacementResult() = delete;
    PlacementResult(std::string _path, std::function<void()> _cleanup) noexcept;
    PlacementResult(PlacementResult&&) noexcept;
    PlacementResult(const PlacementResult&) = delete;
    ~PlacementResult() noexcept;
    
    void operator=(const PlacementResult&) = delete;
    void operator=(PlacementResult&&) = delete;
    
    const std::string &Path() const noexcept;
private:
    std::string m_Path;
    std::function<void()> m_Cleanup;
};
    
}
