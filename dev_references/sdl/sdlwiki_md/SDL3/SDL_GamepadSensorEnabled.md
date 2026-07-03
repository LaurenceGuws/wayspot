# SDL_GamepadSensorEnabled

Query whether sensor data reporting is enabled for a gamepad.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GamepadSensorEnabled(SDL_Gamepad *gamepad, SDL_SensorType type);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | the gamepad to query. |
| [SDL_SensorType](SDL_SensorType.html) | **type** | the type of sensor to query. |

## Return Value

(bool) Returns true if the sensor is enabled, false otherwise.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetGamepadSensorEnabled](SDL_SetGamepadSensorEnabled.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
