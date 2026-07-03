# SDL_GetRealGamepadTypeForID

Get the type of a gamepad, ignoring any mapping override.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GamepadType SDL_GetRealGamepadTypeForID(SDL_JoystickID instance_id);
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

- [SDL_GetGamepadTypeForID](SDL_GetGamepadTypeForID.html)
- [SDL_GetGamepads](SDL_GetGamepads.html)
- [SDL_GetRealGamepadType](SDL_GetRealGamepadType.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
