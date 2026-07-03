# SDL_GetJoystickFromID

Get the [SDL_Joystick](SDL_Joystick.html) associated with an instance
ID, if it has been opened.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Joystick * SDL_GetJoystickFromID(SDL_JoystickID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_JoystickID](SDL_JoystickID.html) | **instance_id** | the instance ID to get the [SDL_Joystick](SDL_Joystick.html) for. |

## Return Value

([SDL_Joystick](SDL_Joystick.html) \*) Returns an
[SDL_Joystick](SDL_Joystick.html) on success or NULL on failure or if it
hasn't been opened yet; call [SDL_GetError](SDL_GetError.html)() for
more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
