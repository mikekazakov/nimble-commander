// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ActionsShortcutsManager.h"
#include <Config/Config.h>
#include <Config/RapidJSON.h>
#include <cassert>
#include <ranges>

namespace nc::core {

// this key should not exist in config defaults
static const auto g_OverridesConfigPath = "hotkeyOverrides_v1";

ActionsShortcutsManager::ActionsShortcutsManager(
    const std::span<const std::pair<const char *, int>> _action_tags,
    const std::span<const std::pair<const char *, const char *>> _default_shortcuts,
    nc::config::Config &_config)
    : m_Config(_config)
{
    static_assert(sizeof(TagsUsingShortcut) == 24);

    // Safety checks against malformed _action_tags, only in Debug builds
    assert((ankerl::unordered_dense::map<std::string_view, int>{_action_tags.begin(), _action_tags.end()}).size() ==
           _action_tags.size());

    // Safety checks against malformed _default_shortcuts, only in Debug builds
    assert((ankerl::unordered_dense::map<std::string_view, std::string_view>{_default_shortcuts.begin(),
                                                                             _default_shortcuts.end()})
               .size() == _default_shortcuts.size());

    m_OriginalOrderedActions.assign(_action_tags.begin(), _action_tags.end());

    // Build the O(1) mapping between the action tags and the action names
    for( auto [action, tag] : _action_tags ) {
        m_ActionToTag.emplace(action, tag);
        m_TagToAction.emplace(tag, action);
    }

    // Set up the shortcut defaults from the hardcoded map
    for( auto [action, shortcut_string] : _default_shortcuts ) {
        if( auto it = m_ActionToTag.find(action); it != m_ActionToTag.end() ) {
            m_ShortcutsDefaults[it->second] = SanitizedShortcuts(Shortcuts{Shortcut{shortcut_string}});
        }
    }

    // Set up the shortcut overrides
    ReadOverrideFromConfig();

    // Set up the shortcut usage map from the defaults and the overrides
    BuildShortcutUsageMap();
}

ActionsShortcutsManager::~ActionsShortcutsManager() = default;

std::optional<int> ActionsShortcutsManager::TagFromAction(std::string_view _action) const noexcept
{
    if( const auto it = m_ActionToTag.find(_action); it != m_ActionToTag.end() )
        return it->second;
    return std::nullopt;
}

std::optional<std::string_view> ActionsShortcutsManager::ActionFromTag(int _tag) const noexcept
{
    if( const auto it = m_TagToAction.find(_tag); it != m_TagToAction.end() )
        return std::string_view{it->second.data(), it->second.size()};
    return std::nullopt;
}

void ActionsShortcutsManager::ReadOverrideFromConfig()
{
    using namespace rapidjson;

    auto v = m_Config.Get(g_OverridesConfigPath);
    if( v.GetType() != kObjectType )
        return;

    m_ShortcutsOverrides.clear();
    for( auto it = v.MemberBegin(), e = v.MemberEnd(); it != e; ++it ) {
        if( it->name.GetType() != kStringType )
            continue;

        const auto att = m_ActionToTag.find(it->name.GetString());
        if( att == m_ActionToTag.end() )
            continue;

        if( it->value.GetType() == kStringType ) {
            m_ShortcutsOverrides[att->second] = SanitizedShortcuts(Shortcuts{Shortcut{it->value.GetString()}});
        }
        if( it->value.GetType() == kArrayType ) {
            Shortcuts shortcuts;
            const unsigned shortcuts_size = it->value.Size();
            for( unsigned idx = 0; idx < shortcuts_size; ++idx ) {
                const auto &shortcut = it->value[idx];
                if( shortcut.IsString() )
                    shortcuts.push_back(Shortcut{shortcut.GetString()});
            }
            m_ShortcutsOverrides[att->second] = SanitizedShortcuts(shortcuts);
        }
    }
}

std::optional<ActionsShortcutsManager::Shortcuts>
ActionsShortcutsManager::ShortcutsFromAction(std::string_view _action) const noexcept
{
    const std::optional<int> tag = TagFromAction(_action);
    if( !tag )
        return {};
    return ShortcutsFromTag(*tag);
}

std::optional<ActionsShortcutsManager::Shortcuts> ActionsShortcutsManager::ShortcutsFromTag(int _tag) const noexcept
{
    if( auto sc_override = m_ShortcutsOverrides.find(_tag); sc_override != m_ShortcutsOverrides.end() ) {
        return sc_override->second;
    }

    if( auto sc_default = m_ShortcutsDefaults.find(_tag); sc_default != m_ShortcutsDefaults.end() ) {
        return sc_default->second;
    }

    return {};
}

std::optional<ActionsShortcutsManager::Shortcuts>
ActionsShortcutsManager::DefaultShortcutsFromTag(int _tag) const noexcept
{
    if( auto sc_default = m_ShortcutsDefaults.find(_tag); sc_default != m_ShortcutsDefaults.end() ) {
        return sc_default->second;
    }
    return {};
}

std::optional<ActionsShortcutsManager::ActionTags>
ActionsShortcutsManager::ActionTagsFromShortcut(const Shortcut _sc, const std::string_view _in_domain) const noexcept
{
    auto it = m_ShortcutsUsage.find(_sc);
    if( it == m_ShortcutsUsage.end() )
        return std::nullopt; // this shortcut is not used at all

    ActionTags tags = it->second;
    if( !_in_domain.empty() ) {
        // need to filter the tag depending to their domain, aka action name prefix
        auto not_in_domain = [&](const int tag) {
            return !ActionFromTag(tag).value_or(std::string_view{}).starts_with(_in_domain);
        };

        auto to_erase = std::ranges::remove_if(tags, not_in_domain);
        tags.erase(to_erase.begin(), to_erase.end());
    }

    if( tags.empty() )
        return std::nullopt;

    return tags;
}

std::optional<int>
ActionsShortcutsManager::FirstOfActionTagsFromShortcut(std::span<const int> _of_tags,
                                                       const Shortcut _sc,
                                                       const std::string_view _in_domain) const noexcept
{
    if( const auto tags = ActionTagsFromShortcut(_sc, _in_domain) ) {
        if( auto it = std::ranges::find_first_of(*tags, _of_tags); it != tags->end() )
            return *it;
    }
    return std::nullopt;
}

bool ActionsShortcutsManager::SetShortcutOverride(const std::string_view _action, const Shortcut _sc)
{
    return SetShortcutsOverride(_action, std::span<const Shortcut>{&_sc, 1});
}

bool ActionsShortcutsManager::SetShortcutsOverride(std::string_view _action, std::span<const Shortcut> _shortcuts)
{
    const std::optional<int> tag = TagFromAction(_action);
    if( !tag )
        return false;

    const auto default_it = m_ShortcutsDefaults.find(*tag);
    if( default_it == m_ShortcutsDefaults.end() )
        return false; // this should never happen

    const Shortcuts new_shortcuts = SanitizedShortcuts(Shortcuts(_shortcuts.begin(), _shortcuts.end()));

    // Search if currently this action has custom shortcuts(s)
    const auto override_it = m_ShortcutsOverrides.find(*tag);

    if( std::ranges::equal(default_it->second, new_shortcuts) ) {
        // The shortcut is same as the default one for this action

        if( override_it == m_ShortcutsOverrides.end() ) {
            // The shortcut of this action was previously overriden - nothing to do
            return false;
        }

        // Unregister the usage of the override shortcuts
        for( const Shortcut &shortcut : override_it->second )
            UnregisterShortcutUsage(shortcut, *tag);

        // Register the usage of the default shortcuts
        for( const Shortcut &shortcut : default_it->second )
            RegisterShortcutUsage(shortcut, *tag);

        // Remove the override
        m_ShortcutsOverrides.erase(*tag);
    }
    else {
        // The shortcut is not the same as the default for this action

        if( override_it != m_ShortcutsOverrides.end() && override_it->second == new_shortcuts ) {
            return false; // Nothing new, it's the same as currently defined in the overrides
        }

        if( override_it == m_ShortcutsOverrides.end() ) {
            // Unregister the usage of the default override shortcuts
            for( const Shortcut &shortcut : default_it->second )
                UnregisterShortcutUsage(shortcut, *tag);
        }
        else {
            // Unregister the usage of the override shortcuts
            for( const Shortcut &shortcut : override_it->second )
                UnregisterShortcutUsage(shortcut, *tag);
        }

        // Register the usage of the new override shortcuts
        for( const Shortcut &shortcut : new_shortcuts )
            RegisterShortcutUsage(shortcut, *tag);

        // Set the override
        m_ShortcutsOverrides[*tag] = new_shortcuts;
    }

    // immediately write to config file
    WriteOverridesToConfig();
    return true;
}

void ActionsShortcutsManager::RevertToDefaults()
{
    m_ShortcutsOverrides.clear();
    WriteOverridesToConfig();
}

void ActionsShortcutsManager::WriteOverridesToConfig() const
{
    using namespace rapidjson;
    nc::config::Value overrides{kObjectType};

    for( auto &i : m_OriginalOrderedActions ) {
        auto scover = m_ShortcutsOverrides.find(i.second);
        if( scover == m_ShortcutsOverrides.end() ) {
            continue;
        }
        if( scover->second.size() < 2 ) {
            const std::string shortcut = scover->second.empty() ? std::string{} : scover->second.front().ToPersString();
            overrides.AddMember(nc::config::MakeStandaloneString(i.first),
                                nc::config::MakeStandaloneString(shortcut),
                                nc::config::g_CrtAllocator);
        }
        else {
            nc::config::Value shortcuts{kArrayType};
            for( const Shortcut &sc : scover->second ) {
                shortcuts.PushBack(nc::config::MakeStandaloneString(sc.ToPersString()), nc::config::g_CrtAllocator);
            }
            overrides.AddMember(nc::config::MakeStandaloneString(i.first), shortcuts, nc::config::g_CrtAllocator);
        }
    }

    m_Config.Set(g_OverridesConfigPath, overrides);
}

std::vector<std::pair<std::string, int>> ActionsShortcutsManager::AllShortcuts() const
{
    return m_OriginalOrderedActions;
}

void ActionsShortcutsManager::RegisterShortcutUsage(const Shortcut _shortcut, const int _tag) noexcept
{
    assert(static_cast<bool>(_shortcut)); // only non-empty shortcuts should be registered
    if( !static_cast<bool>(_shortcut) )
        return;

    if( auto it = m_ShortcutsUsage.find(_shortcut); it == m_ShortcutsUsage.end() ) {
        // this shortcut wasn't used before
        m_ShortcutsUsage[_shortcut].push_back(_tag);
    }
    else {
        // this shortcut was already used. Add the tag only if it's not already there - preserve uniqueness
        if( std::ranges::find(it->second, _tag) == it->second.end() ) {
            it->second.push_back(_tag);
        }
    }
}

void ActionsShortcutsManager::UnregisterShortcutUsage(Shortcut _shortcut, int _tag) noexcept
{
    if( auto it = m_ShortcutsUsage.find(_shortcut); it != m_ShortcutsUsage.end() ) {
        auto &tags = it->second;

        auto to_erase = std::ranges::remove(tags, _tag);
        tags.erase(to_erase.begin(), to_erase.end());

        if( tags.empty() ) {
            // No need to keep an empty record in the usage map
            m_ShortcutsUsage.erase(it);
        }
    }
}

void ActionsShortcutsManager::BuildShortcutUsageMap() noexcept
{
    m_ShortcutsUsage.clear(); // build the map means starting from scratch

    for( const auto &[tag, default_shortcuts] : m_ShortcutsDefaults ) {
        if( const auto it = m_ShortcutsOverrides.find(tag); it != m_ShortcutsOverrides.end() ) {
            for( const Shortcut &shortcut : it->second ) {
                if( shortcut )
                    RegisterShortcutUsage(shortcut, tag);
            }
        }
        else {
            for( const Shortcut &shortcut : default_shortcuts ) {
                if( shortcut )
                    RegisterShortcutUsage(shortcut, tag);
            }
        }
    }
}

ActionsShortcutsManager::Shortcuts ActionsShortcutsManager::SanitizedShortcuts(const Shortcuts &_shortcuts) noexcept
{
    Shortcuts shortcuts = _shortcuts;

    // Remove any empty shortcuts.
    {
        auto to_erase = std::ranges::remove_if(shortcuts, [](const Shortcut &_sc) { return _sc == Shortcut{}; });
        shortcuts.erase(to_erase.begin(), to_erase.end());
    }

    // Remove any duplicates.
    // Technically speaking this is O(N^2), but N is normally ~= 1, so it doesn't matter.
    for( auto it = shortcuts.begin(); it != shortcuts.end(); ++it ) {
        shortcuts.erase(std::remove_if(std::next(it), shortcuts.end(), [&](const Shortcut &_sc) { return _sc == *it; }),
                        shortcuts.end());
    }

    return shortcuts;
}

} // namespace nc::core
