# SDL_UpdateHapticEffect

Update the properties of an effect.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_UpdateHapticEffect(SDL_Haptic *haptic, SDL_HapticEffectID effect, const SDL_HapticEffect *data);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | the [SDL_Haptic](SDL_Haptic.html) device that has the effect. |
| [SDL_HapticEffectID](SDL_HapticEffectID.html) | **effect** | the identifier of the effect to update. |
| const [SDL_HapticEffect](SDL_HapticEffect.html) \* | **data** | an [SDL_HapticEffect](SDL_HapticEffect.html) structure containing the new effect properties to use. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Can be used dynamically, although behavior when dynamically changing
direction may be strange. Specifically the effect may re-upload itself
and start playing from the start. You also cannot change the type either
when running [SDL_UpdateHapticEffect](SDL_UpdateHapticEffect.html)().

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateHapticEffect](SDL_CreateHapticEffect.html)
- [SDL_RunHapticEffect](SDL_RunHapticEffect.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
