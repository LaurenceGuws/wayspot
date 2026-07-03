# SDL_GetHapticNameForID

Get the implementation dependent name of a haptic device.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetHapticNameForID(SDL_HapticID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_HapticID](SDL_HapticID.html) | **instance_id** | the haptic device instance ID. |

## Return Value

(const char \*) Returns the name of the selected haptic device. If no
name can be found, this function returns NULL; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This can be called before any haptic devices are opened.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetHapticName](SDL_GetHapticName.html)
- [SDL_OpenHaptic](SDL_OpenHaptic.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
