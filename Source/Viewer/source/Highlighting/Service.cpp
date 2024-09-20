// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Viewer/Highlighting/LexerSettings.h> // NOLINT
#include <Viewer/Highlighting/Highlighter.h>   // NOLINT

#include <cstdio>
#include <fmt/format.h>
#include <optional>
#include <span>
#include <xpc/xpc.h>

static void send_reply_error(xpc_connection_t _peer, xpc_object_t _from_event, const std::string &_error_msg) noexcept
{
    xpc_object_t reply = xpc_dictionary_create_reply(_from_event);
    if( reply == nullptr ) {
        return;
    }
    xpc_dictionary_set_string(reply, "error", _error_msg.c_str());
    xpc_connection_send_message(_peer, reply);
    xpc_release(reply);
}

static void send_reply_styles(xpc_connection_t _peer,
                              xpc_object_t _from_event,
                              std::span<const nc::viewer::hl::Style> _styles) noexcept
{
    xpc_object_t reply = xpc_dictionary_create_reply(_from_event);
    if( reply == nullptr ) {
        return;
    }
    xpc_dictionary_set_data(reply, "response", _styles.data(), _styles.size() * sizeof(nc::viewer::hl::Style));
    xpc_connection_send_message(_peer, reply);
    xpc_release(reply);
}

static void peer_event_handler(xpc_connection_t _peer, xpc_object_t _event) noexcept
{
    const xpc_type_t type = xpc_get_type(_event);
    if( type == XPC_TYPE_ERROR ) {
        if( _event == XPC_ERROR_TERMINATION_IMMINENT ) {
            exit(0);
        }
        return;
    }

    if( type != XPC_TYPE_DICTIONARY ) {
        send_reply_error(_peer, _event, "The request type must be dictionary.");
        return;
    }

    size_t text_size = 0;
    const void *text = xpc_dictionary_get_data(_event, "text", &text_size);
    if( !text ) {
        send_reply_error(_peer, _event, "Unable to find the 'text' field in the request.");
        return;
    }

    size_t settings_size = 0;
    const void *settings = xpc_dictionary_get_data(_event, "settings", &settings_size);
    if( !settings ) {
        send_reply_error(_peer, _event, "Unable to find the 'settings' field in the request.");
        return;
    }

    auto parsed_settings =
        nc::viewer::hl::ParseLexerSettings(std::string_view{static_cast<const char *>(settings), settings_size});
    if( !parsed_settings ) {
        send_reply_error(
            _peer, _event, fmt::format("Unable to parse the lexing settings: '{}'", parsed_settings.error()));
        return;
    }

    try {
        const nc::viewer::hl::Highlighter highlighter{std::move(*parsed_settings)};
        const std::string_view document{static_cast<const char *>(text), text_size};
        const std::vector<nc::viewer::hl::Style> styles = highlighter.Highlight(document);
        send_reply_styles(_peer, _event, styles);
    } catch( std::exception &ex ) {
        send_reply_error(_peer, _event, fmt::format("Unable to highlight the document: '{}'", ex.what()));
    }
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
