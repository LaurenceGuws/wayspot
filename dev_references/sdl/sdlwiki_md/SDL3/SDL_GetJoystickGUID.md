# SDL_GetJoystickGUID

Get the implementation-dependent GUID for the joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GUID SDL_GetJoystickGUID(SDL_Joystick *joystick);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Joystick](SDL_Joystick.html) \* | **joystick** | the [SDL_Joystick](SDL_Joystick.html) obtained from [SDL_OpenJoystick](SDL_OpenJoystick.html)(). |

## Return Value

([SDL_GUID](SDL_GUID.html)) Returns the GUID of the given joystick. If
called on an invalid index, this function returns a zero GUID; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function requires an open joystick.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetJoystickGUIDForID](SDL_GetJoystickGUIDForID.html)
- [SDL_GUIDToString](SDL_GUIDToString.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
