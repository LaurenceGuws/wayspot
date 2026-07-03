# SDL_GamepadDeviceEvent

Gamepad device event structure (event.gdevice.\*)

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GamepadDeviceEvent
{
    SDL_EventType type; /**< SDL_EVENT_GAMEPAD_ADDED, SDL_EVENT_GAMEPAD_REMOVED, or SDL_EVENT_GAMEPAD_REMAPPED, SDL_EVENT_GAMEPAD_UPDATE_COMPLETE or SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED */
    Uint32 reserved;
    Uint64 timestamp;   /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_JoystickID which;       /**< The joystick instance id */
} SDL_GamepadDeviceEvent;
```

</div>

## Remarks

Joysticks that are supported gamepads receive both an
[SDL_JoyDeviceEvent](SDL_JoyDeviceEvent.html) and an
[SDL_GamepadDeviceEvent](SDL_GamepadDeviceEvent.html).

SDL will send GAMEPAD_ADDED events for joysticks that are already
plugged in during [SDL_Init](SDL_Init.html)() and are recognized as
gamepads. It will also send events for joysticks that get gamepad
mappings at runtime.

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_JoyDeviceEvent](SDL_JoyDeviceEvent.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryEvents](CategoryEvents.html)
