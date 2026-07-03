# SDL_GetMaxHapticEffectsPlaying

Get the number of effects a haptic device can play at the same time.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetMaxHapticEffectsPlaying(SDL_Haptic *haptic);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | the [SDL_Haptic](SDL_Haptic.html) device to query maximum playing effects. |

## Return Value

(int) Returns the number of effects the haptic device can play at the
same time or -1 on failure; call [SDL_GetError](SDL_GetError.html)() for
more information.

## Remarks

This is not supported on all platforms, but will always return a value.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetMaxHapticEffects](SDL_GetMaxHapticEffects.html)
- [SDL_GetHapticFeatures](SDL_GetHapticFeatures.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
