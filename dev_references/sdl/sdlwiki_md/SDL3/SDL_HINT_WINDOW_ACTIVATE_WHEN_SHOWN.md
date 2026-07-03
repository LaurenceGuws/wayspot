# SDL_HINT_WINDOW_ACTIVATE_WHEN_SHOWN

A variable controlling whether the window is activated when the
[SDL_ShowWindow](SDL_ShowWindow.html) function is called.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_WINDOW_ACTIVATE_WHEN_SHOWN "SDL_WINDOW_ACTIVATE_WHEN_SHOWN"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": The window is not activated when the
  [SDL_ShowWindow](SDL_ShowWindow.html) function is called.
- "1": The window is activated when the
  [SDL_ShowWindow](SDL_ShowWindow.html) function is called. (default)

This hint can be set anytime.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
