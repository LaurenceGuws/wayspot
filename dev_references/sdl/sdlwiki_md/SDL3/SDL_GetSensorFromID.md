# SDL_GetSensorFromID

Return the [SDL_Sensor](SDL_Sensor.html) associated with an instance ID.

## Header File

Defined in
[\<SDL3/SDL_sensor.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_sensor.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Sensor * SDL_GetSensorFromID(SDL_SensorID instance_id);
```

</div>

## Function Parameters

|                                   |                 |                         |
|-----------------------------------|-----------------|-------------------------|
| [SDL_SensorID](SDL_SensorID.html) | **instance_id** | the sensor instance ID. |

## Return Value

([SDL_Sensor](SDL_Sensor.html) \*) Returns an
[SDL_Sensor](SDL_Sensor.html) object or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySensor](CategorySensor.html)
