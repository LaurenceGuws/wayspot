# CategorySensor

SDL sensor management.

These APIs grant access to gyros and accelerometers on various
platforms.

In order to use these functions, [SDL_Init](SDL_Init.html)() must have
been called with the [SDL_INIT_SENSOR](SDL_INIT_SENSOR.html) flag. This
causes SDL to scan the system for sensors, and load appropriate drivers.

## Functions

- [SDL_CloseSensor](SDL_CloseSensor.html)
- [SDL_GetSensorData](SDL_GetSensorData.html)
- [SDL_GetSensorFromID](SDL_GetSensorFromID.html)
- [SDL_GetSensorID](SDL_GetSensorID.html)
- [SDL_GetSensorName](SDL_GetSensorName.html)
- [SDL_GetSensorNameForID](SDL_GetSensorNameForID.html)
- [SDL_GetSensorNonPortableType](SDL_GetSensorNonPortableType.html)
- [SDL_GetSensorNonPortableTypeForID](SDL_GetSensorNonPortableTypeForID.html)
- [SDL_GetSensorProperties](SDL_GetSensorProperties.html)
- [SDL_GetSensors](SDL_GetSensors.html)
- [SDL_GetSensorType](SDL_GetSensorType.html)
- [SDL_GetSensorTypeForID](SDL_GetSensorTypeForID.html)
- [SDL_OpenSensor](SDL_OpenSensor.html)
- [SDL_UpdateSensors](SDL_UpdateSensors.html)

## Datatypes

- [SDL_Sensor](SDL_Sensor.html)
- [SDL_SensorID](SDL_SensorID.html)

## Structs

- (none.)

## Enums

- [SDL_SensorType](SDL_SensorType.html)

## Macros

- [SDL_STANDARD_GRAVITY](SDL_STANDARD_GRAVITY.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
