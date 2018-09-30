#include "NonPersistentOverwritesStorage.h"

namespace nc::config {

NonPersistentOverwritesStorage::NonPersistentOverwritesStorage(std::string_view _initial_value):
    m_Data(_initial_value)
{
}
    
NonPersistentOverwritesStorage::~NonPersistentOverwritesStorage()
{
}
    
void NonPersistentOverwritesStorage::ExternalWrite( const std::string &_new_value )
{
    m_Data = _new_value;
    if( m_Callback )
        m_Callback();
}
    
std::optional<std::string> NonPersistentOverwritesStorage::Read() const
{
    return std::make_optional(m_Data);
}
    
void NonPersistentOverwritesStorage::Write(const std::string &_overwrites_json)
{
    m_Data = _overwrites_json;
}
    
void NonPersistentOverwritesStorage::SetExternalChangeCallback( std::function<void()> _callback)
{
    m_Callback = std::move(_callback);
}

}
