// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::bootstrap {
    
class ActivationManagerBase
{
public:
    
    class ExternalLicenseSupport
    {
    public:
        ExternalLicenseSupport();
        ExternalLicenseSupport( std::string _test_public_key );
        
        
        bool CheckLicenseValidity( const std::string &_path );
        
    private:
        std::string m_PublicKey;
    };
    
    
};
    
}
