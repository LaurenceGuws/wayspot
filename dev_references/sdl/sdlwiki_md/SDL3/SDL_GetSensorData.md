# SDL_GetSensorData

Get the current state of an opened sensor.

## Header File

Defined in
[\<SDL3/SDL_sensor.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_sensor.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetSensorData(SDL_Sensor *sensor, float *data, int num_values);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Sensor](SDL_Sensor.html) \* | **sensor** | the [SDL_Sensor](SDL_Sensor.html) object to query. |
| float \* | **data** | a pointer filled with the current sensor state. |
| int | **num_values** | the number of values to write to data. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The number of values and interpretation of the data is sensor dependent.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySensor](CategorySensor.html)
