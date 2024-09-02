// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/algo.h>
#include <Viewer/Highlighting/Client.h>
#include <Viewer/Log.h>
#include <cassert>
#include <thread>
#include <xpc/xpc.h>

namespace nc::viewer::hl {

static constexpr auto g_ServiceName = "com.magnumbytes.NimbleCommander.Highlighter";

std::expected<std::vector<Style>, std::string> Client::Highlight(std::string_view _text, std::string_view _settings)
{
    Log::Trace("Client::Highlight called");

    xpc_connection_t connection = xpc_connection_create(g_ServiceName, nullptr);
    if( connection == nullptr ) {
        Log::Error("Failed to create an XPC connection");
        return std::unexpected<std::string>("Failed to create an XPC connection");
    }
    auto release_connection = at_scope_end([&] { xpc_release(connection); });

    xpc_connection_set_event_handler(connection, ^(xpc_object_t _event) {
      const xpc_type_t type = xpc_get_type(_event);
      if( type == XPC_TYPE_ERROR ) {
          if( _event == XPC_ERROR_CONNECTION_INTERRUPTED ) {
              Log::Error("XPC connection interrupted");
          }
          else if( _event == XPC_ERROR_CONNECTION_INVALID ) {
              Log::Error("XPC connection invalid");
          }
          else {
              Log::Error("XPC unknown error");
          }
      }
    });

    xpc_connection_resume(connection);

    xpc_object_t message = xpc_dictionary_create(nullptr, nullptr, 0);
    xpc_dictionary_set_data(message, "text", _text.data(), _text.size());
    xpc_dictionary_set_data(message, "settings", _settings.data(), _settings.size());
    auto release_message = at_scope_end([&] { xpc_release(message); });

    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, message);
    auto release_reply = at_scope_end([&] { xpc_release(reply); });
    Log::Trace("Got a response from the XPC service");

    const xpc_type_t reply_type = xpc_get_type(reply);
    if( reply_type == XPC_TYPE_ERROR ) {
        if( reply == XPC_ERROR_CONNECTION_INTERRUPTED ) {
            Log::Error("XPC connection interrupted");
            return std::unexpected<std::string>("XPC connection interrupted");
        }
        else if( reply == XPC_ERROR_CONNECTION_INVALID ) {
            Log::Error("XPC connection invalid");
            return std::unexpected<std::string>("XPC connection invalid");
        }
        else {
            Log::Error("XPC unknown error");
            return std::unexpected<std::string>("XPC unknown error");
        }
    }

    if( reply_type != XPC_TYPE_DICTIONARY ) {
        Log::Error("XPC reply is not a dictionary");
        return std::unexpected<std::string>("XPC reply is not a dictionary");
    }

    if( const char *error_str = xpc_dictionary_get_string(reply, "error") ) {
        Log::Error("Error while highlighting: {}", error_str);
        return std::unexpected<std::string>(error_str);
    }

    size_t styles_size = 0;
    const void *styles = xpc_dictionary_get_data(reply, "response", &styles_size);
    if( !styles ) {
        Log::Error("The reply doesn't contain a 'response' field");
        return std::unexpected<std::string>("The reply doesn't contain a 'response' field");
    }
    Log::Info("Got styles from the XPC service, {}b long", styles_size);

    std::vector<Style> out(static_cast<const Style *>(styles), static_cast<const Style *>(styles) + styles_size);

    return out;
}

void Client::HighlightAsync(std::string_view _text,
                            std::string_view _settings,
                            std::function<void(std::expected<std::vector<Style>, std::string>)> _done,
                            dispatch_queue_t _queue)
{
    assert(_done);
    Log::Trace("Client::HighlightAsync called");

    if( _queue == nullptr ) {
        _queue = dispatch_get_main_queue();
    }

    xpc_connection_t connection = xpc_connection_create(g_ServiceName, _queue);
    if( connection == nullptr ) {
        Log::Error("Failed to create an XPC connection");
        _done(std::unexpected<std::string>("Failed to create an XPC connection"));
    }

    auto handler = ^(xpc_object_t _reply) {
      Log::Trace("Got a response from the XPC service");
      const xpc_type_t type = xpc_get_type(_reply);
      if( type == XPC_TYPE_ERROR ) {
          if( _reply == XPC_ERROR_CONNECTION_INTERRUPTED ) {
              Log::Error("XPC connection interrupted");
              _done(std::unexpected<std::string>("XPC connection interrupted"));
              return;
          }
          else if( _reply == XPC_ERROR_CONNECTION_INVALID ) {
              Log::Error("XPC connection invalid");
              _done(std::unexpected<std::string>("XPC connection invalid"));
              return;
          }
          else {
              Log::Error("XPC unknown error");
              _done(std::unexpected<std::string>("XPC unknown error"));
              return;
          }
      }
      else if( type == XPC_TYPE_DICTIONARY ) {
          if( const char *error_str = xpc_dictionary_get_string(_reply, "error") ) {
              Log::Error("Error while highlighting: {}", error_str);
              _done(std::unexpected<std::string>(error_str));
              return;
          }

          size_t styles_size = 0;
          const void *styles = xpc_dictionary_get_data(_reply, "response", &styles_size);
          if( !styles ) {
              Log::Error("The reply doesn't contain a 'response' field");
              _done(std::unexpected<std::string>("The reply doesn't contain a 'response' field"));
              return;
          }
          Log::Info("Got styles from the XPC service, {}b long", styles_size);

          std::vector<Style> out(static_cast<const Style *>(styles), static_cast<const Style *>(styles) + styles_size);

          _done(std::move(out));
      }
      else {
          Log::Error("XPC reply is not a dictionary");
          _done(std::unexpected<std::string>("XPC reply is not a dictionary"));
          return;
      }
    };

    xpc_connection_set_event_handler(connection, handler);
    xpc_connection_resume(connection);

    xpc_object_t message = xpc_dictionary_create(nullptr, nullptr, 0);
    xpc_dictionary_set_data(message, "text", _text.data(), _text.size());
    xpc_dictionary_set_data(message, "settings", _settings.data(), _settings.size());
    auto release_message = at_scope_end([&] { xpc_release(message); });

    xpc_connection_send_message_with_reply(connection, message, _queue, handler);

    // VVV I seriously don't understand the ownership model of xpc_connection_t and why this seem to be correct...
    xpc_release(connection);
}

} // namespace nc::viewer::hl
