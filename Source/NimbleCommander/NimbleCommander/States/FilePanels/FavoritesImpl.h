// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Favorites.h"
#include <Config/Config.h>
#include <ankerl/unordered_dense.h>

namespace nc::panel {

class PanelDataPersistency;

// STA API design at the moment, call it only from main thread!
class FavoriteLocationsStorageImpl : public FavoriteLocationsStorage
{
public:
    FavoriteLocationsStorageImpl(config::Config &_config, const char *_path, PanelDataPersistency &_persistency);
    void StoreData(config::Config &_config, const char *_path);

    void AddFavoriteLocation(Favorite _favorite) override;

    std::optional<Favorite> ComposeFavoriteLocation(VFSHost &_host,
                                                    const std::string &_directory,
                                                    const std::string &_title = "") const override;

    void SetFavorites(const std::vector<Favorite> &_new_favorites) override;
    std::vector<Favorite> Favorites(/*limit output later?*/) const override;

    // Recent locations management
    void ReportLocationVisit(VFSHost &_host, const std::string &_directory) override;
    std::vector<std::shared_ptr<const Location>> FrecentlyUsed(int _amount) const override;
    void ClearVisitedLocations() override;

    ObservationTicket ObserveFavoritesChanges(std::function<void()> _callback) override;

private:
    enum ObservationEvents : uint64_t {
        FavoritesChanged = 1
    };

    struct Visit {
        std::shared_ptr<const Location> location;
        int visits_count = 0;
        time_t last_visit = 0;
    };

    std::shared_ptr<const Location>
    FindInVisitsOrEncode(size_t _footprint, VFSHost &_host, const std::string &_directory);

    std::shared_ptr<const FavoriteLocationsStorage::Location> Encode(const VFSHost &_host,
                                                                     const std::string &_directory) const;

    void LoadData(config::Config &_config, const char *_path);

    nc::config::Value VisitToJSON(const Visit &_visit);
    std::optional<Visit> JSONToVisit(const nc::config::Value &_json);

    nc::config::Value FavoriteToJSON(const Favorite &_favorite);
    std::optional<Favorite> JSONToFavorite(const nc::config::Value &_json);

    PanelDataPersistency &m_Persistency;

    ankerl::unordered_dense::map<size_t, Visit> m_Visits;
    std::vector<Favorite> m_Favorites;
};

} // namespace nc::panel
