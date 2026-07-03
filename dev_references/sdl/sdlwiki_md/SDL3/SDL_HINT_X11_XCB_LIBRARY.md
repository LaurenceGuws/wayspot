# SDL_HINT_X11_XCB_LIBRARY

Specify the XCB library to load for the X11 driver.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_X11_XCB_LIBRARY "SDL_X11_XCB_LIBRARY"
```

</div>

## Remarks

The default is platform-specific, often "libX11-xcb.so.1".

This hint should be set before initializing the video subsystem.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
