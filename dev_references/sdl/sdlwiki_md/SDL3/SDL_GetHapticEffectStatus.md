# SDL_GetHapticEffectStatus

Get the status of the current effect on the specified haptic device.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetHapticEffectStatus(SDL_Haptic *haptic, SDL_HapticEffectID effect);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | the [SDL_Haptic](SDL_Haptic.html) device to query for the effect status on. |
| [SDL_HapticEffectID](SDL_HapticEffectID.html) | **effect** | the ID of the haptic effect to query its status. |

## Return Value

(bool) Returns true if it is playing, false if it isn't playing or
haptic status isn't supported.

## Remarks

Device must support the [SDL_HAPTIC_STATUS](SDL_HAPTIC_STATUS.html)
feature.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetHapticFeatures](SDL_GetHapticFeatures.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
