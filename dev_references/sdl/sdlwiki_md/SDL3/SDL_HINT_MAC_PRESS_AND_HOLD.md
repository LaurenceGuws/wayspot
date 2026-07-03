# SDL_HINT_MAC_PRESS_AND_HOLD

A variable controlling whether holding down a key will repeat the
pressed key or open the accents menu on macOS.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_MAC_PRESS_AND_HOLD "SDL_MAC_PRESS_AND_HOLD"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": Holding a key will repeat the pressed key.
- "1": Holding a key will open the accents menu for that key. (default)

This hint needs to be set before [SDL_Init](SDL_Init.html)().

## Version

This hint is available since SDL 3.4.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
