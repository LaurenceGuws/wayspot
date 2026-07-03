# SDL_GetSensors

Get a list of currently connected sensors.

## Header File

Defined in
[\<SDL3/SDL_sensor.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_sensor.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_SensorID * SDL_GetSensors(int *count);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| int \* | **count** | a pointer filled in with the number of sensors returned, may be NULL. |

## Return Value

([SDL_SensorID](SDL_SensorID.html) \*) Returns a 0 terminated array of
sensor instance IDs or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information. This should be
freed with [SDL_free](SDL_free.html)() when it is no longer needed.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySensor](CategorySensor.html)
