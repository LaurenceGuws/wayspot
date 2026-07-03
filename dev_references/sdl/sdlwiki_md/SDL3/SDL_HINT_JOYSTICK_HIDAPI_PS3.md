# SDL_HINT_JOYSTICK_HIDAPI_PS3

A variable controlling whether the HIDAPI driver for PS3 controllers
should be used.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_JOYSTICK_HIDAPI_PS3 "SDL_JOYSTICK_HIDAPI_PS3"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": HIDAPI driver is not used.
- "1": HIDAPI driver is used.

The default is the value of
[SDL_HINT_JOYSTICK_HIDAPI](SDL_HINT_JOYSTICK_HIDAPI.html) on macOS, and
"0" on other platforms.

For official Sony driver (sixaxis.sys) use
[SDL_HINT_JOYSTICK_HIDAPI_PS3_SIXAXIS_DRIVER](SDL_HINT_JOYSTICK_HIDAPI_PS3_SIXAXIS_DRIVER.html).
See <https://github.com/ViGEm/DsHidMini> for an alternative driver on
Windows.

This hint should be set before initializing joysticks and gamepads.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
