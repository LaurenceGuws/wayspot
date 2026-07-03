# SDL_SetJoystickVirtualBall

Generate ball motion on an opened virtual joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetJoystickVirtualBall(SDL_Joystick *joystick, int ball, Sint16 xrel, Sint16 yrel);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Joystick](SDL_Joystick.html) \* | **joystick** | the virtual joystick on which to set state. |
| int | **ball** | the index of the ball on the virtual joystick to update. |
| [Sint16](Sint16.html) | **xrel** | the relative motion on the X axis. |
| [Sint16](Sint16.html) | **yrel** | the relative motion on the Y axis. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Please note that values set here will not be applied until the next call
to [SDL_UpdateJoysticks](SDL_UpdateJoysticks.html), which can either be
called directly, or can be called indirectly through various other SDL
APIs, including, but not limited to the following:
[SDL_PollEvent](SDL_PollEvent.html),
[SDL_PumpEvents](SDL_PumpEvents.html),
[SDL_WaitEventTimeout](SDL_WaitEventTimeout.html),
[SDL_WaitEvent](SDL_WaitEvent.html).

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetJoystickVirtualAxis](SDL_SetJoystickVirtualAxis.html)
- [SDL_SetJoystickVirtualButton](SDL_SetJoystickVirtualButton.html)
- [SDL_SetJoystickVirtualHat](SDL_SetJoystickVirtualHat.html)
- [SDL_SetJoystickVirtualTouchpad](SDL_SetJoystickVirtualTouchpad.html)
- [SDL_SetJoystickVirtualSensorData](SDL_SetJoystickVirtualSensorData.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
