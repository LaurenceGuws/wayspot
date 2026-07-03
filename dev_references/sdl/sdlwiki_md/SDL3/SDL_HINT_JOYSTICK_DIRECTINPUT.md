# SDL_HINT_JOYSTICK_DIRECTINPUT

A variable controlling whether DirectInput should be used for
controllers.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_JOYSTICK_DIRECTINPUT "SDL_JOYSTICK_DIRECTINPUT"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": Disable DirectInput detection.
- "1": Enable DirectInput detection. (default)

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
