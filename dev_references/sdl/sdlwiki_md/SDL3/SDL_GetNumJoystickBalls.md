# SDL_GetNumJoystickBalls

Get the number of trackballs on a joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetNumJoystickBalls(SDL_Joystick *joystick);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Joystick](SDL_Joystick.html) \* | **joystick** | an [SDL_Joystick](SDL_Joystick.html) structure containing joystick information. |

## Return Value

(int) Returns the number of trackballs on success or -1 on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Joystick trackballs have only relative motion events associated with
them and their state cannot be polled.

Most joysticks do not have trackballs.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetJoystickBall](SDL_GetJoystickBall.html)
- [SDL_GetNumJoystickAxes](SDL_GetNumJoystickAxes.html)
- [SDL_GetNumJoystickButtons](SDL_GetNumJoystickButtons.html)
- [SDL_GetNumJoystickHats](SDL_GetNumJoystickHats.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
