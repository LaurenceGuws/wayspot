# SDL_GetGamepadSensorDataRate

Get the data rate (number of events per second) of a gamepad sensor.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
float SDL_GetGamepadSensorDataRate(SDL_Gamepad *gamepad, SDL_SensorType type);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | the gamepad to query. |
| [SDL_SensorType](SDL_SensorType.html) | **type** | the type of sensor to query. |

## Return Value

(float) Returns the data rate, or 0.0f if the data rate is not
available.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
