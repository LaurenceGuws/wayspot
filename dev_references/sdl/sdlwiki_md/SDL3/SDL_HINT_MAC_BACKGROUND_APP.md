# SDL_HINT_MAC_BACKGROUND_APP

A variable controlling whether to force the application to become the
foreground process when launched on macOS.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_MAC_BACKGROUND_APP "SDL_MAC_BACKGROUND_APP"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": The application is brought to the foreground when launched.
  (default)
- "1": The application may remain in the background when launched.

This hint needs to be set before [SDL_Init](SDL_Init.html)().

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
