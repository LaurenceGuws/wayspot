# SDL_SetGamepadSensorEnabled

Set whether data reporting for a gamepad sensor is enabled.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetGamepadSensorEnabled(SDL_Gamepad *gamepad, SDL_SensorType type, bool enabled);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | the gamepad to update. |
| [SDL_SensorType](SDL_SensorType.html) | **type** | the type of sensor to enable/disable. |
| bool | **enabled** | whether data reporting should be enabled. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GamepadHasSensor](SDL_GamepadHasSensor.html)
- [SDL_GamepadSensorEnabled](SDL_GamepadSensorEnabled.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
