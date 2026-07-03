# SDL_GetHapticFromID

Get the [SDL_Haptic](SDL_Haptic.html) associated with an instance ID, if
it has been opened.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Haptic * SDL_GetHapticFromID(SDL_HapticID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_HapticID](SDL_HapticID.html) | **instance_id** | the instance ID to get the [SDL_Haptic](SDL_Haptic.html) for. |

## Return Value

([SDL_Haptic](SDL_Haptic.html) \*) Returns an
[SDL_Haptic](SDL_Haptic.html) on success or NULL on failure or if it
hasn't been opened yet; call [SDL_GetError](SDL_GetError.html)() for
more information.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
