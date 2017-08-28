#pragma once 

namespace nc::vfs::webdav {

time_t DateTimeFromRFC1123( const char *_date_time );
time_t DateTimeFromRFC850( const char *_date_time );
time_t DateTimeFromRFC3339( const char *_date_time );
time_t DateTimeFromASCTime( const char *_date_time );

}
