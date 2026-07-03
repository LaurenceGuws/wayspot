# SDL_HINT_WINDOWS_ERASE_BACKGROUND_MODE

A variable controlling whether SDL will clear the window contents when
the WM_ERASEBKGND message is received.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_WINDOWS_ERASE_BACKGROUND_MODE "SDL_WINDOWS_ERASE_BACKGROUND_MODE"
```

</div>

## Remarks

The variable can be set to the following values:

- "0"/"never": Never clear the window.
- "1"/"initial": Clear the window when the first WM_ERASEBKGND event
  fires. (default)
- "2"/"always": Clear the window on every WM_ERASEBKGND event.

This hint should be set before creating a window.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
