# SDL_GetSensorNonPortableType

Get the platform dependent type of a sensor.

## Header File

Defined in
[\<SDL3/SDL_sensor.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_sensor.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetSensorNonPortableType(SDL_Sensor *sensor);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Sensor](SDL_Sensor.html) \* | **sensor** | the [SDL_Sensor](SDL_Sensor.html) object to inspect. |

## Return Value

(int) Returns the sensor platform dependent type, or -1 if `sensor` is
NULL.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySensor](CategorySensor.html)
