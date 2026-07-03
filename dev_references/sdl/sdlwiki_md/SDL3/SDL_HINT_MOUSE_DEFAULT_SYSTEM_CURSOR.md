# SDL_HINT_MOUSE_DEFAULT_SYSTEM_CURSOR

A variable setting which system cursor to use as the default cursor.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_MOUSE_DEFAULT_SYSTEM_CURSOR "SDL_MOUSE_DEFAULT_SYSTEM_CURSOR"
```

</div>

## Remarks

This should be an integer corresponding to the
[SDL_SystemCursor](SDL_SystemCursor.html) enum. The default value is
zero ([SDL_SYSTEM_CURSOR_DEFAULT](SDL_SYSTEM_CURSOR_DEFAULT.html)).

This hint needs to be set before [SDL_Init](SDL_Init.html)().

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
