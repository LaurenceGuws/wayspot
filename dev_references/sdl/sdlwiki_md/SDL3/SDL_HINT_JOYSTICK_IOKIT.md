# SDL_HINT_JOYSTICK_IOKIT

A variable controlling whether IOKit should be used for controller
handling.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_JOYSTICK_IOKIT "SDL_JOYSTICK_IOKIT"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": IOKit is not used.
- "1": IOKit is used. (default)

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
