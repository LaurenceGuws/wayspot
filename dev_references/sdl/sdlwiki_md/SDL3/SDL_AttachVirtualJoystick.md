# SDL_AttachVirtualJoystick

Attach a new virtual joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_JoystickID SDL_AttachVirtualJoystick(const SDL_VirtualJoystickDesc *desc);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const [SDL_VirtualJoystickDesc](SDL_VirtualJoystickDesc.html) \* | **desc** | joystick description, initialized using [SDL_INIT_INTERFACE](SDL_INIT_INTERFACE.html)(). |

## Return Value

([SDL_JoystickID](SDL_JoystickID.html)) Returns the joystick instance
ID, or 0 on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Remarks

Apps can create virtual joysticks, that exist without hardware directly
backing them, and have program-supplied inputs. Once attached, a virtual
joystick looks like any other joystick that SDL can access. These can be
used to make other things look like joysticks, or provide pre-recorded
input, etc.

Once attached, the app can send joystick inputs to the new virtual
joystick using
[SDL_SetJoystickVirtualAxis](SDL_SetJoystickVirtualAxis.html)(), etc.

When no longer needed, the virtual joystick can be removed by calling
[SDL_DetachVirtualJoystick](SDL_DetachVirtualJoystick.html)().

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_DetachVirtualJoystick](SDL_DetachVirtualJoystick.html)
- [SDL_SetJoystickVirtualAxis](SDL_SetJoystickVirtualAxis.html)
- [SDL_SetJoystickVirtualButton](SDL_SetJoystickVirtualButton.html)
- [SDL_SetJoystickVirtualBall](SDL_SetJoystickVirtualBall.html)
- [SDL_SetJoystickVirtualHat](SDL_SetJoystickVirtualHat.html)
- [SDL_SetJoystickVirtualTouchpad](SDL_SetJoystickVirtualTouchpad.html)
- [SDL_SetJoystickVirtualSensorData](SDL_SetJoystickVirtualSensorData.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
