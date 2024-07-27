# Implementation Notes - Syntax Highlighting
*This brief document explains the design and some implementation details of how syntax highlighting works in Nimble Commander's built-in viewer.*

## Styles Definitions

Nimble Commander relies on [Lexilla](https://github.com/ScintillaOrg/lexilla) for lexing and styling.

This library provides a multitude of different styles with complex relationships, which is excessive for the built-in viewer.

To simplify the styling logic, Nimble Commander currently uses only eight styles:
  - Default (non-styled text)
  - Comment
  - Preprocessor
  - Keyword
  - Operator
  - Identifier
  - Number
  - String

Themes can define colors for each of these styles. For example:
```js
{
    "viewerTextColor": "#000000",
    "viewerTextSyntaxCommentColor": "#267507",
    "viewerTextSyntaxPreprocessorColor": "#643820",
    "viewerTextSyntaxKeywordColor": "#9B2393",
    "viewerTextSyntaxOperatorColor": "#121249",
    "viewerTextSyntaxIdentifierColor": "#000000",
    "viewerTextSyntaxNumberColor": "#1C00CF",
    "viewerTextSyntaxStringColor": "#C41A16"
}
```

To make this work, [each of the styles](https://github.com/ScintillaOrg/lexilla/blob/master/include/SciLexer.h) for a specific lexer must be mapped to one of Nimble Commander’s styles.

## Settings Files

This mapping is specified in a settings file for each supported language.

Here's an example of such settings file:
```js
{
    "lexer": "json",
    "wordlists": [
        "false true null"
    ],
    "properties": {
        "lexer.json.escape.sequence": "1",
        "lexer.json.allow.comments": "1"
    },
    "mapping": {
        "SCE_JSON_DEFAULT": "default",
        "SCE_JSON_NUMBER": "number",
        "SCE_JSON_STRING": "string",
        "SCE_JSON_STRINGEOL": "string",
        "SCE_JSON_PROPERTYNAME": "keyword",
        "SCE_JSON_ESCAPESEQUENCE": "string",
        "SCE_JSON_LINECOMMENT": "comment",
        "SCE_JSON_BLOCKCOMMENT": "comment",
        "SCE_JSON_OPERATOR": "operator",
        "SCE_JSON_URI": "string",
        "SCE_JSON_COMPACTIRI": "string",
        "SCE_JSON_KEYWORD": "keyword",
        "SCE_JSON_LDKEYWORD": "keyword",
        "SCE_JSON_ERROR": "preprocessor"
    }
}
```

In addition to the styles mapping, the settings file also provides the name of the lexer to be used, lists of keywords, and lexer properties.

These JSON files are located in the application's `SyntaxHighlighting` directory, shipped with the application. This directory also contains the `Main.json` file, which defines the list of known languages, their file masks, and the filenames of the settings for each language. 

Nimble Commander supports overriding these settings with files placed in the `~/Library/Application Support/Nimble Commander/SyntaxHighlighting` directory. Any file will first be looked for in the `Application Support` directory, and if not found, in the application directory. Changes in the overrides directory will be automatically picked up by Nimble Commander, and the next time the Viewer is shown, the updated settings will be used.

## Helper Tool

Since lexing arbitrary untrusted data is risky, this process is separated from the main application.

This functionality is contained in a small XPC helper tool called 'Highlighter'.

The main application communicates with the helper by providing it with UTF-8 text to highlight and settings with the rules that define the syntax and styles mapping.

Once ready, the helper tool responds back with a single blob of data containing styles: 1 byte per each input UTF-8 code unit.

The await process is asynchronous on Nimble Commander’s side to avoid freezing the whole application. However, the built-in viewer allows up to 16ms of synchronous wait before falling back to deferred highlighting. This way, visual flicker is avoided.

## Adding More Languages

To add syntax highlighting for a new language, follow these steps:
  - Ensure that Lexilla has a lexer for the languge.
  - Create a JSON file for the configugation in `Source/NimbleCommander/NimbleCommander/Resources/SyntaxHighlighting`.  
    Use the existing settings files as examples.
  - Add the ID of the lexer in the configuration file (e.g. "bash", "cmake", "xml").  
    The ID can be found at the bottom of the lexer implementation file.  
    Refer to the [Lexilla lexers]( https://github.com/ScintillaOrg/lexilla/blob/master/lexers/) to locate the file.
  - Specify one or multipe lists of language keywords, separated by spaces.
  - Include any required lexer properties.
  - Map the Scintilla styles to Nimble Commander styles in the configuration file.
  - In the `Main.json` file, add the new configuration file, give it a name and a filemask to determine when to use this syntax.
