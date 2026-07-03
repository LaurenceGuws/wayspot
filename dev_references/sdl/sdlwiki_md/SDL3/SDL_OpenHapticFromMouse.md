# SDL_OpenHapticFromMouse

Try to open a haptic device from the current mouse.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Haptic * SDL_OpenHapticFromMouse(void);
```

</div>

## Return Value

([SDL_Haptic](SDL_Haptic.html) \*) Returns the haptic device identifier
or NULL on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CloseHaptic](SDL_CloseHaptic.html)
- [SDL_IsMouseHaptic](SDL_IsMouseHaptic.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
