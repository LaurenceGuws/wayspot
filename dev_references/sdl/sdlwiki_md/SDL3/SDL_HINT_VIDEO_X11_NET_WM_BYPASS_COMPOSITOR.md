# SDL_HINT_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR

A variable controlling whether the X11 \_NET_WM_BYPASS_COMPOSITOR hint
should be used.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR "SDL_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": Disable \_NET_WM_BYPASS_COMPOSITOR.
- "1": Enable \_NET_WM_BYPASS_COMPOSITOR. (default)

This hint should be set before creating a window.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
