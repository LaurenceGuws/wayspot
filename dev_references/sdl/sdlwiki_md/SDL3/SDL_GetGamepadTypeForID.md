# SDL_GetGamepadTypeForID

Get the type of a gamepad.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GamepadType SDL_GetGamepadTypeForID(SDL_JoystickID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_JoystickID](SDL_JoystickID.html) | **instance_id** | the joystick instance ID. |

## Return Value

([SDL_GamepadType](SDL_GamepadType.html)) Returns the gamepad type.

## Remarks

This can be called before any gamepads are opened.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetGamepadType](SDL_GetGamepadType.html)
- [SDL_GetGamepads](SDL_GetGamepads.html)
- [SDL_GetRealGamepadTypeForID](SDL_GetRealGamepadTypeForID.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
