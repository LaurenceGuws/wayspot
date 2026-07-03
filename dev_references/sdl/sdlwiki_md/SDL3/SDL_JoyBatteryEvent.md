# SDL_JoyBatteryEvent

Joystick battery level change event structure (event.jbattery.\*)

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_JoyBatteryEvent
{
    SDL_EventType type; /**< SDL_EVENT_JOYSTICK_BATTERY_UPDATED */
    Uint32 reserved;
    Uint64 timestamp;   /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which; /**< The joystick instance id */
    SDL_PowerState state; /**< The joystick battery state */
    int percent;          /**< The joystick battery percent charge remaining */
} SDL_JoyBatteryEvent;
```

</div>

## Version

This struct is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryEvents](CategoryEvents.html)
