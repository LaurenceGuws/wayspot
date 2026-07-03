# SDL_SetJoystickVirtualAxis

Set the state of an axis on an opened virtual joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetJoystickVirtualAxis(SDL_Joystick *joystick, int axis, Sint16 value);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Joystick](SDL_Joystick.html) \* | **joystick** | the virtual joystick on which to set state. |
| int | **axis** | the index of the axis on the virtual joystick to update. |
| [Sint16](Sint16.html) | **value** | the new value for the specified axis. |

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

Note that when sending trigger axes, you should scale the value to the
full range of [Sint16](Sint16.html). For example, a trigger at rest
would have the value of
[`SDL_JOYSTICK_AXIS_MIN`](SDL_JOYSTICK_AXIS_MIN.html).

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetJoystickVirtualButton](SDL_SetJoystickVirtualButton.html)
- [SDL_SetJoystickVirtualBall](SDL_SetJoystickVirtualBall.html)
- [SDL_SetJoystickVirtualHat](SDL_SetJoystickVirtualHat.html)
- [SDL_SetJoystickVirtualTouchpad](SDL_SetJoystickVirtualTouchpad.html)
- [SDL_SetJoystickVirtualSensorData](SDL_SetJoystickVirtualSensorData.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
