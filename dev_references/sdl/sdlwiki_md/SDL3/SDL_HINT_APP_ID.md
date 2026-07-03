# SDL_HINT_APP_ID

A variable setting the app ID string.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_APP_ID "SDL_APP_ID"
```

</div>

## Remarks

This string is used by desktop compositors to identify and group windows
together, as well as match applications with associated desktop settings
and icons.

This will override
[SDL_PROP_APP_METADATA_IDENTIFIER_STRING](SDL_PROP_APP_METADATA_IDENTIFIER_STRING.html),
if set by the application.

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
