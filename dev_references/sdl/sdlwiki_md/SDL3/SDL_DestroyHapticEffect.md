# SDL_DestroyHapticEffect

Destroy a haptic effect on the device.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroyHapticEffect(SDL_Haptic *haptic, SDL_HapticEffectID effect);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | the [SDL_Haptic](SDL_Haptic.html) device to destroy the effect on. |
| [SDL_HapticEffectID](SDL_HapticEffectID.html) | **effect** | the ID of the haptic effect to destroy. |

## Remarks

This will stop the effect if it's running. Effects are automatically
destroyed when the device is closed.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateHapticEffect](SDL_CreateHapticEffect.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
