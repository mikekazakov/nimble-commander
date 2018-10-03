// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Config.h"

namespace nc::config {

Token Config::CreateToken(unsigned long _number)
{
    return Token{this, _number};
}

void Config::Discard(const Token &_token)
{
    assert( _token.m_Token != 0 );
    DropToken(_token.m_Token);
}

Token::Token(Config *_instance, unsigned long _token) noexcept :
    m_Instance(_instance),
    m_Token(_token)
{
}
    
Token::Token(Token &&_rhs) noexcept:
    m_Instance(_rhs.m_Instance),
    m_Token(_rhs.m_Token)
{
    _rhs.m_Instance = nullptr;
    _rhs.m_Token = 0;
}

Token::~Token()
{
    if( *this )
        m_Instance->Discard(*this);
}    
    
const Token &Token::operator=(Token &&_rhs)
{
    if( *this )
        m_Instance->Discard(*this);
    m_Instance = _rhs.m_Instance;
    m_Token = _rhs.m_Token;
    _rhs.m_Instance = nullptr;
    _rhs.m_Token = 0;
    return *this;
}

Token::operator bool() const noexcept
{
    return m_Instance != nullptr && m_Token != 0;
}

}
