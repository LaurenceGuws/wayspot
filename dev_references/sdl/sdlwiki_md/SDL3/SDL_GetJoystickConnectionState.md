# SDL_GetJoystickConnectionState

Get the connection state of a joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_JoystickConnectionState SDL_GetJoystickConnectionState(SDL_Joystick *joystick);
```

</div>

## Function Parameters

|                                      |              |                        |
|--------------------------------------|--------------|------------------------|
| [SDL_Joystick](SDL_Joystick.html) \* | **joystick** | the joystick to query. |

## Return Value

([SDL_JoystickConnectionState](SDL_JoystickConnectionState.html))
Returns the connection state on success or
[`SDL_JOYSTICK_CONNECTION_INVALID`](SDL_JOYSTICK_CONNECTION_INVALID.html)
on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
