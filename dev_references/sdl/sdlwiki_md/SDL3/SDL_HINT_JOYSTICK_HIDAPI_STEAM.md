# SDL_HINT_JOYSTICK_HIDAPI_STEAM

A variable controlling whether the HIDAPI driver for Bluetooth Steam
Controllers should be used.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_JOYSTICK_HIDAPI_STEAM "SDL_JOYSTICK_HIDAPI_STEAM"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": HIDAPI driver is not used. (default)
- "1": HIDAPI driver is used for Steam Controllers, which requires
  Bluetooth access and may prompt the user for permission on iOS and
  Android.

This hint should be set before initializing joysticks and gamepads.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
