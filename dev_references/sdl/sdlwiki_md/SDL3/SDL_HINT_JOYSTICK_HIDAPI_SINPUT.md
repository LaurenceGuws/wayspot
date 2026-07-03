# SDL_HINT_JOYSTICK_HIDAPI_SINPUT

A variable controlling whether the HIDAPI driver for SInput controllers
should be used.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_JOYSTICK_HIDAPI_SINPUT "SDL_JOYSTICK_HIDAPI_SINPUT"
```

</div>

## Remarks

More info - <https://github.com/HandHeldLegend/SInput-HID>

The variable can be set to the following values:

- "0": HIDAPI driver is not used.
- "1": HIDAPI driver is used.

The default is the value of
[SDL_HINT_JOYSTICK_HIDAPI](SDL_HINT_JOYSTICK_HIDAPI.html).

This hint should be set before initializing joysticks and gamepads.

## Version

This hint is available since SDL 3.4.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
