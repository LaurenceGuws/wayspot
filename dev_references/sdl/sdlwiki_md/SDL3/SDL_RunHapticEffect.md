# SDL_RunHapticEffect

Run the haptic effect on its associated haptic device.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RunHapticEffect(SDL_Haptic *haptic, SDL_HapticEffectID effect, Uint32 iterations);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | the [SDL_Haptic](SDL_Haptic.html) device to run the effect on. |
| [SDL_HapticEffectID](SDL_HapticEffectID.html) | **effect** | the ID of the haptic effect to run. |
| [Uint32](Uint32.html) | **iterations** | the number of iterations to run the effect; use [`SDL_HAPTIC_INFINITY`](SDL_HAPTIC_INFINITY.html) to repeat forever. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

To repeat the effect over and over indefinitely, set `iterations` to
[`SDL_HAPTIC_INFINITY`](SDL_HAPTIC_INFINITY.html). (Repeats the
envelope - attack and fade.) To make one instance of the effect last
indefinitely (so the effect does not fade), set the effect's `length` in
its structure/union to [`SDL_HAPTIC_INFINITY`](SDL_HAPTIC_INFINITY.html)
instead.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetHapticEffectStatus](SDL_GetHapticEffectStatus.html)
- [SDL_StopHapticEffect](SDL_StopHapticEffect.html)
- [SDL_StopHapticEffects](SDL_StopHapticEffects.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
