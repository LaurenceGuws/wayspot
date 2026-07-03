# SDL_OpenGamepad

Open a gamepad for use.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Gamepad * SDL_OpenGamepad(SDL_JoystickID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_JoystickID](SDL_JoystickID.html) | **instance_id** | the joystick instance ID. |

## Return Value

([SDL_Gamepad](SDL_Gamepad.html) \*) Returns a gamepad identifier or
NULL if an error occurred; call [SDL_GetError](SDL_GetError.html)() for
more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CloseGamepad](SDL_CloseGamepad.html)
- [SDL_IsGamepad](SDL_IsGamepad.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
