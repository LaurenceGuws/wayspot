# SDL_GetNumJoystickAxes

Get the number of general axis controls on a joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetNumJoystickAxes(SDL_Joystick *joystick);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Joystick](SDL_Joystick.html) \* | **joystick** | an [SDL_Joystick](SDL_Joystick.html) structure containing joystick information. |

## Return Value

(int) Returns the number of axis controls/number of axes on success or
-1 on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Remarks

Often, the directional pad on a game controller will either look like 4
separate buttons or a POV hat, and not axes, but all of this is up to
the device and platform.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetJoystickAxis](SDL_GetJoystickAxis.html)
- [SDL_GetNumJoystickBalls](SDL_GetNumJoystickBalls.html)
- [SDL_GetNumJoystickButtons](SDL_GetNumJoystickButtons.html)
- [SDL_GetNumJoystickHats](SDL_GetNumJoystickHats.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
