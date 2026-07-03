# SDL_GetMaxHapticEffects

Get the number of effects a haptic device can store.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetMaxHapticEffects(SDL_Haptic *haptic);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | the [SDL_Haptic](SDL_Haptic.html) device to query. |

## Return Value

(int) Returns the number of effects the haptic device can store or a
negative error code on failure; call [SDL_GetError](SDL_GetError.html)()
for more information.

## Remarks

On some platforms this isn't fully supported, and therefore is an
approximation. Always check to see if your created effect was actually
created and do not rely solely on
[SDL_GetMaxHapticEffects](SDL_GetMaxHapticEffects.html)().

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetMaxHapticEffectsPlaying](SDL_GetMaxHapticEffectsPlaying.html)
- [SDL_GetHapticFeatures](SDL_GetHapticFeatures.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
