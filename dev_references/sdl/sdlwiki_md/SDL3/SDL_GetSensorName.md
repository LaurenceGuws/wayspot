# SDL_GetSensorName

Get the implementation dependent name of a sensor.

## Header File

Defined in
[\<SDL3/SDL_sensor.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_sensor.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetSensorName(SDL_Sensor *sensor);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Sensor](SDL_Sensor.html) \* | **sensor** | the [SDL_Sensor](SDL_Sensor.html) object. |

## Return Value

(const char \*) Returns the sensor name or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySensor](CategorySensor.html)
