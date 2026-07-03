# SDL_GetGamepadMappingForGUID

Get the gamepad mapping string for a given GUID.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
char * SDL_GetGamepadMappingForGUID(SDL_GUID guid);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GUID](SDL_GUID.html) | **guid** | a structure containing the GUID for which a mapping is desired. |

## Return Value

(char \*) Returns a mapping string or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information. This should be
freed with [SDL_free](SDL_free.html)() when it is no longer needed.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetJoystickGUIDForID](SDL_GetJoystickGUIDForID.html)
- [SDL_GetJoystickGUID](SDL_GetJoystickGUID.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
