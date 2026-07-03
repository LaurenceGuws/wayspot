# SDL_HINT_HIDAPI_ENUMERATE_ONLY_CONTROLLERS

A variable to control whether
[SDL_hid_enumerate](SDL_hid_enumerate.html)() enumerates all HID devices
or only controllers.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_HIDAPI_ENUMERATE_ONLY_CONTROLLERS "SDL_HIDAPI_ENUMERATE_ONLY_CONTROLLERS"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": [SDL_hid_enumerate](SDL_hid_enumerate.html)() will enumerate all
  HID devices.
- "1": [SDL_hid_enumerate](SDL_hid_enumerate.html)() will only enumerate
  controllers. (default)

By default SDL will only enumerate controllers, to reduce risk of
hanging or crashing on devices with bad drivers and avoiding macOS
keyboard capture permission prompts.

This hint can be set anytime.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
