# SDL_OpenJoystick

Open a joystick for use.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Joystick * SDL_OpenJoystick(SDL_JoystickID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_JoystickID](SDL_JoystickID.html) | **instance_id** | the joystick instance ID. |

## Return Value

([SDL_Joystick](SDL_Joystick.html) \*) Returns a joystick identifier or
NULL on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Remarks

The joystick subsystem must be initialized before a joystick can be
opened for use.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CloseJoystick](SDL_CloseJoystick.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
