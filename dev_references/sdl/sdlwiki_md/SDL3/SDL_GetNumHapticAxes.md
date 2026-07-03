# SDL_GetNumHapticAxes

Get the number of haptic axes the device has.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetNumHapticAxes(SDL_Haptic *haptic);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | the [SDL_Haptic](SDL_Haptic.html) device to query. |

## Return Value

(int) Returns the number of axes on success or -1 on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The number of haptic axes might be useful if working with the
[SDL_HapticDirection](SDL_HapticDirection.html) effect.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
