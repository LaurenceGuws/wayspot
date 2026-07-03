# SDL_HINT_JOYSTICK_MFI

A variable controlling whether GCController should be used for
controller handling.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_JOYSTICK_MFI "SDL_JOYSTICK_MFI"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": GCController is not used.
- "1": GCController is used. (default)

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
