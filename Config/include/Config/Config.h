// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string_view>
#include <string>
#include <functional>
#include "RapidJSON_fwd.h"

namespace nc::config {

class Token;    

class Config
{
public:
    virtual ~Config() = default;
    
    /**
     * Returns true if the config contains a value at the specified path.
     */
    virtual bool Has(std::string_view _path) const = 0;
    
    /**
     * Returns null when a value can't be found.
     */
    virtual Value Get(std::string_view _path) const = 0;

    /**
     * Returns null when a value can't be found.
     */    
    virtual Value GetDefault(std::string_view _path) const = 0;
    
    /**
     * Returns "" when a value can't be found.
     */    
    virtual std::string GetString(std::string_view _path) const = 0;
    
    /**
     * Returns false when a value can't be found.
     */
    virtual bool GetBool(std::string_view _path) const = 0;
    
    /**
     * Returns 0 when a value can't be found.
     */
    virtual int GetInt(std::string_view _path) const = 0;

    /**
     * Returns 0 when a value can't be found.
     */
    virtual unsigned int GetUInt(std::string_view _path) const = 0;
    
    /**
     * Returns 0 when a value can't be found.
     */    
    virtual long GetLong(std::string_view _path) const = 0;

    /**
     * Returns 0 when a value can't be found.
     */
    virtual unsigned long GetULong(std::string_view _path) const = 0;
    
    /**
     * Returns 0. when a value can't be found.
     */     
    virtual double GetDouble(std::string_view _path) const = 0;

    virtual void Set(std::string_view _path, const Value &_value) = 0;
    virtual void Set(std::string_view _path, int _value) = 0;
    virtual void Set(std::string_view _path, unsigned int _value) = 0;
    virtual void Set(std::string_view _path, long _value) = 0;
    virtual void Set(std::string_view _path, unsigned long _value) = 0;
    virtual void Set(std::string_view _path, double _value) = 0;
    virtual void Set(std::string_view _path, bool _value) = 0;
    virtual void Set(std::string_view _path, const char *_value) = 0;
    virtual void Set(std::string_view _path, std::string_view _value) = 0;
   
    /**
     * Sets an observation for changes on the specified path.
     * _on_change callback can be fired from any thread.
     * _on_change can be called only while the returned token object is alive.
     * it's guaranteed that _on_change will not be called after the returned token was destroyed.
     * It is safe to destroy the token (i.e. unregister) from the callback itself.
     */
    virtual Token Observe(std::string_view _path, std::function<void()> _on_change) = 0;

    template <typename C, typename T>
    void ObserveMany(C &_storage, std::function<void()> _on_change, const T &_paths);
        
    /**
     * Like Observe, but does not provide a way to unregister the observation callback.
     */
    virtual void ObserveForever(std::string_view _path, std::function<void()> _on_change) = 0;
    
protected:    
    Token CreateToken(unsigned long _number);
    virtual void DropToken(unsigned long _number) = 0;
    
private:
    void Discard(const Token &_token);
    friend Token;
};

class Token
{
public:
    Token() = default;
    Token(Token &&) noexcept;
    ~Token();
    
    const Token &operator=(Token &&);
    
    operator bool() const noexcept;
    
private:
    Token(Config *_instance, unsigned long _token) noexcept;
    Token(const Token&) = delete;
    void operator=(const Token&) = delete;
    Config *m_Instance = nullptr;
    unsigned long m_Token = 0;
    friend class Config;
};

template <typename C, typename T>
inline void Config::ObserveMany(C &_storage, std::function<void()> _on_change, const T &_paths)
{
    for( const auto &i: _paths )
        _storage.emplace_back( Observe(i, _on_change) );
}    

}
