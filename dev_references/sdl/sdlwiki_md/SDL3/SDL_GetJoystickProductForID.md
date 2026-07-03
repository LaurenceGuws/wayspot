# SDL_GetJoystickProductForID

Get the USB product ID of a joystick, if available.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Uint16 SDL_GetJoystickProductForID(SDL_JoystickID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_JoystickID](SDL_JoystickID.html) | **instance_id** | the joystick instance ID. |

## Return Value

([Uint16](Uint16.html)) Returns the USB product ID of the selected
joystick. If called with an invalid instance_id, this function returns
0.

## Remarks

This can be called before any joysticks are opened. If the product ID
isn't available this function returns 0.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetJoystickProduct](SDL_GetJoystickProduct.html)
- [SDL_GetJoysticks](SDL_GetJoysticks.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
