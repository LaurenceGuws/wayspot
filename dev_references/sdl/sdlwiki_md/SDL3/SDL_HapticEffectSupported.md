# SDL_HapticEffectSupported

Check to see if an effect is supported by a haptic device.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_HapticEffectSupported(SDL_Haptic *haptic, const SDL_HapticEffect *effect);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | the [SDL_Haptic](SDL_Haptic.html) device to query. |
| const [SDL_HapticEffect](SDL_HapticEffect.html) \* | **effect** | the desired effect to query. |

## Return Value

(bool) Returns true if the effect is supported or false if it isn't.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateHapticEffect](SDL_CreateHapticEffect.html)
- [SDL_GetHapticFeatures](SDL_GetHapticFeatures.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
