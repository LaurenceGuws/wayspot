# SDL_HINT_MAC_SCROLL_MOMENTUM

A variable controlling whether
[SDL_EVENT_MOUSE_WHEEL](SDL_EVENT_MOUSE_WHEEL.html) event values will
have momentum on macOS.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_MAC_SCROLL_MOMENTUM "SDL_MAC_SCROLL_MOMENTUM"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": The mouse wheel events will have no momentum. (default)
- "1": The mouse wheel events will have momentum.

This hint needs to be set before [SDL_Init](SDL_Init.html)().

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
