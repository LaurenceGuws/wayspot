# SDL_GetJoystickPath

Get the implementation dependent path of a joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetJoystickPath(SDL_Joystick *joystick);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Joystick](SDL_Joystick.html) \* | **joystick** | the [SDL_Joystick](SDL_Joystick.html) obtained from [SDL_OpenJoystick](SDL_OpenJoystick.html)(). |

## Return Value

(const char \*) Returns the path of the selected joystick. If no path
can be found, this function returns NULL; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetJoystickPathForID](SDL_GetJoystickPathForID.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
