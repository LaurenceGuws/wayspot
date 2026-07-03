# SDL_GetNumJoystickHats

Get the number of POV hats on a joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetNumJoystickHats(SDL_Joystick *joystick);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Joystick](SDL_Joystick.html) \* | **joystick** | an [SDL_Joystick](SDL_Joystick.html) structure containing joystick information. |

## Return Value

(int) Returns the number of POV hats on success or -1 on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetJoystickHat](SDL_GetJoystickHat.html)
- [SDL_GetNumJoystickAxes](SDL_GetNumJoystickAxes.html)
- [SDL_GetNumJoystickBalls](SDL_GetNumJoystickBalls.html)
- [SDL_GetNumJoystickButtons](SDL_GetNumJoystickButtons.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
