// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Highlighting/LexerSettings.h>
#include <Viewer/Highlighting/Highlighter.h>
#include <stdio.h>
#include <xpc/xpc.h>

static void peer_event_handler(xpc_connection_t _peer, xpc_object_t _event)
{
    const xpc_type_t type = xpc_get_type(_event);

    if( type == XPC_TYPE_DICTIONARY ) {
        size_t text_size = 0;
        const void *text = xpc_dictionary_get_data(_event, "text", &text_size);
        if( !text ) {
            // TODO: error handling
            abort();
        }

        size_t settings_size = 0;
        const void *settings = xpc_dictionary_get_data(_event, "settings", &settings_size);
        if( !settings ) {
            // TODO: error handling
            abort();
        }

        auto parsed_settings =
            nc::viewer::hl::ParseLexerSettings(std::string_view{static_cast<const char *>(settings), settings_size});
        if( !parsed_settings ) {
            // TODO: error handling
            abort();
        }

        nc::viewer::hl::Highlighter highlighter{std::move(*parsed_settings)};
        std::vector<nc::viewer::hl::Style> styles =
            highlighter.Highlight(std::string_view{static_cast<const char *>(text), text_size});

        xpc_object_t reply = xpc_dictionary_create_reply(_event);
        if( !reply ) {
            // TODO: error handling
            abort();
        }

        xpc_dictionary_set_data(reply, "response", styles.data(), styles.size() * sizeof(nc::viewer::hl::Style));

        xpc_connection_send_message(_peer, reply);
        xpc_release(reply);
    }
//    else {
//        // TODO: error handling
//        abort();
//    }
}

static void event_handler(xpc_connection_t _connection)
{
    xpc_connection_set_event_handler(_connection, ^(xpc_object_t _event) {
      peer_event_handler(_connection, _event);
    });
    xpc_connection_resume(_connection);
}

int main([[maybe_unused]] int _argc, [[maybe_unused]] const char *_argv[])
{
    xpc_main(event_handler);
}
