// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Highlighting/Client.h>
#include <xpc/xpc.h>
#include <assert.h>
#include <thread>

namespace nc::viewer::hl {

static constexpr auto g_ServiceName = "com.magnumbytes.NimbleCommander.Highlighter";

// TODO: integrate with Logger

std::vector<Style> Client::Highlight(std::string_view _text, std::string_view _settings)
{
    xpc_connection_t connection = xpc_connection_create(g_ServiceName, nullptr);
    assert(connection);

    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
      xpc_type_t type = xpc_get_type(event);

      if( type == XPC_TYPE_ERROR ) {
          if( event == XPC_ERROR_CONNECTION_INTERRUPTED ) {
              printf("Connection interrupted.\n");
          }
          else if( event == XPC_ERROR_CONNECTION_INVALID ) {
              printf("Connection invalid.\n");
          }
          else {
              printf("Unknown error.\n");
          }
      }
      else if( type == XPC_TYPE_DICTIONARY ) {
          const char *response = xpc_dictionary_get_string(event, "response");
          printf("Received response: %s\n", response);
      }
    });

    xpc_connection_resume(connection);

    xpc_object_t message = xpc_dictionary_create(nullptr, nullptr, 0);
    xpc_dictionary_set_data(message, "text", _text.data(), _text.size());
    xpc_dictionary_set_data(message, "settings", _settings.data(), _settings.size());

    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, message);
    xpc_release(message);

    size_t styles_size = 0;
    const void *styles = xpc_dictionary_get_data(reply, "response", &styles_size);
    if( !styles ) {
        // TODO: error handling
        abort();
    }

    std::vector<Style> out(static_cast<const Style *>(styles), static_cast<const Style *>(styles) + styles_size);

    xpc_release(reply);

    xpc_release(connection);

    return out;
}

} // namespace nc::viewer::hl
