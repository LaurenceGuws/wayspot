# SDL_HINT_JOYSTICK_THREAD

A variable controlling whether a separate thread should be used for
handling joystick detection and raw input messages on Windows.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_JOYSTICK_THREAD "SDL_JOYSTICK_THREAD"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": A separate thread is not used.
- "1": A separate thread is used for handling raw input messages.
  (default)

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
