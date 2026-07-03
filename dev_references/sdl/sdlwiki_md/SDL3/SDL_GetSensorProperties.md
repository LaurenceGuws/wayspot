# SDL_GetSensorProperties

Get the properties associated with a sensor.

## Header File

Defined in
[\<SDL3/SDL_sensor.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_sensor.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_PropertiesID SDL_GetSensorProperties(SDL_Sensor *sensor);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Sensor](SDL_Sensor.html) \* | **sensor** | the [SDL_Sensor](SDL_Sensor.html) object. |

## Return Value

([SDL_PropertiesID](SDL_PropertiesID.html)) Returns a valid property ID
on success or 0 on failure; call [SDL_GetError](SDL_GetError.html)() for
more information.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySensor](CategorySensor.html)
