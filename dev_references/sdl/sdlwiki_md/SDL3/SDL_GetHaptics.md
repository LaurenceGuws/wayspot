# SDL_GetHaptics

Get a list of currently connected haptic devices.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_HapticID * SDL_GetHaptics(int *count);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| int \* | **count** | a pointer filled in with the number of haptic devices returned, may be NULL. |

## Return Value

([SDL_HapticID](SDL_HapticID.html) \*) Returns a 0 terminated array of
haptic device instance IDs or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information. This should be
freed with [SDL_free](SDL_free.html)() when it is no longer needed.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_OpenHaptic](SDL_OpenHaptic.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
