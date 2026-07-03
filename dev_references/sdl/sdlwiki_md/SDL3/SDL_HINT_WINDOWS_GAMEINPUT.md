# SDL_HINT_WINDOWS_GAMEINPUT

A variable controlling whether GameInput is used for raw keyboard and
mouse on Windows.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_WINDOWS_GAMEINPUT "SDL_WINDOWS_GAMEINPUT"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": GameInput is not used for raw keyboard and mouse events.
  (default)
- "1": GameInput is used for raw keyboard and mouse events, if
  available.

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
