# SDL_CreateHapticEffect

Create a new haptic effect on a specified device.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_HapticEffectID SDL_CreateHapticEffect(SDL_Haptic *haptic, const SDL_HapticEffect *effect);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | an [SDL_Haptic](SDL_Haptic.html) device to create the effect on. |
| const [SDL_HapticEffect](SDL_HapticEffect.html) \* | **effect** | an [SDL_HapticEffect](SDL_HapticEffect.html) structure containing the properties of the effect to create. |

## Return Value

([SDL_HapticEffectID](SDL_HapticEffectID.html)) Returns the ID of the
effect on success or -1 on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_DestroyHapticEffect](SDL_DestroyHapticEffect.html)
- [SDL_RunHapticEffect](SDL_RunHapticEffect.html)
- [SDL_UpdateHapticEffect](SDL_UpdateHapticEffect.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
