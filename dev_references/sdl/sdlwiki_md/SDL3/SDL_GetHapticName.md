# SDL_GetHapticName

Get the implementation dependent name of a haptic device.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetHapticName(SDL_Haptic *haptic);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | the [SDL_Haptic](SDL_Haptic.html) obtained from [SDL_OpenJoystick](SDL_OpenJoystick.html)(). |

## Return Value

(const char \*) Returns the name of the selected haptic device. If no
name can be found, this function returns NULL; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetHapticNameForID](SDL_GetHapticNameForID.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
