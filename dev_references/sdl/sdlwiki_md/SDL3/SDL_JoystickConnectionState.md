# SDL_JoystickConnectionState

Possible connection states for a joystick device.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_JoystickConnectionState
{
    SDL_JOYSTICK_CONNECTION_INVALID = -1,
    SDL_JOYSTICK_CONNECTION_UNKNOWN,
    SDL_JOYSTICK_CONNECTION_WIRED,
    SDL_JOYSTICK_CONNECTION_WIRELESS
} SDL_JoystickConnectionState;
```

</div>

## Remarks

This is used by
[SDL_GetJoystickConnectionState](SDL_GetJoystickConnectionState.html) to
report how a device is connected to the system.

## Version

This enum is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html),
[CategoryJoystick](CategoryJoystick.html)
