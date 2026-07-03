# SDL_HINT_AUTO_UPDATE_JOYSTICKS

A variable controlling whether SDL updates joystick state when getting
input events.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_AUTO_UPDATE_JOYSTICKS "SDL_AUTO_UPDATE_JOYSTICKS"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": You'll call [SDL_UpdateJoysticks](SDL_UpdateJoysticks.html)()
  manually.
- "1": SDL will automatically call
  [SDL_UpdateJoysticks](SDL_UpdateJoysticks.html)(). (default)

This hint can be set anytime.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
