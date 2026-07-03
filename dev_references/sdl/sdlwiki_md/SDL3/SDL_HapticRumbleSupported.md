# SDL_HapticRumbleSupported

Check whether rumble is supported on a haptic device.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_HapticRumbleSupported(SDL_Haptic *haptic);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | haptic device to check for rumble support. |

## Return Value

(bool) Returns true if the effect is supported or false if it isn't.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_InitHapticRumble](SDL_InitHapticRumble.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
