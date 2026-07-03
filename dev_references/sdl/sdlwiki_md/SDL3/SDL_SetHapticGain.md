# SDL_SetHapticGain

Set the global gain of the specified haptic device.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetHapticGain(SDL_Haptic *haptic, int gain);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | the [SDL_Haptic](SDL_Haptic.html) device to set the gain on. |
| int | **gain** | value to set the gain to, should be between 0 and 100 (0 - 100). |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Device must support the [SDL_HAPTIC_GAIN](SDL_HAPTIC_GAIN.html) feature.

The user may specify the maximum gain by setting the environment
variable [`SDL_HAPTIC_GAIN_MAX`](SDL_HAPTIC_GAIN_MAX.html) which should
be between 0 and 100. All calls to
[SDL_SetHapticGain](SDL_SetHapticGain.html)() will scale linearly using
[`SDL_HAPTIC_GAIN_MAX`](SDL_HAPTIC_GAIN_MAX.html) as the maximum.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetHapticFeatures](SDL_GetHapticFeatures.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
