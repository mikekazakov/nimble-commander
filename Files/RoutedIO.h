//
//  RoutedIO.h
//  Files
//
//  Created by Michael G. Kazakov on 29/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once


class RoutedIO
{
public:
    RoutedIO();
    static RoutedIO& Instance();
    
    bool Enabled();
    
    
    
    bool TurnOn();
    
    
    bool AskToInstallHelper();
    
    
    bool IsHelperInstalled();
    bool IsHelperCurrent();
    
    
    bool IsHelperAlive();
    xpc_connection_t Connection();
    
private:
    RoutedIO(RoutedIO&) = delete;
    void operator=(RoutedIO&) = delete;
    bool Connect();
    bool ConnectionAvailable();
  
    bool             m_Enabled    = false;
    xpc_connection_t m_Connection = nullptr;
};
