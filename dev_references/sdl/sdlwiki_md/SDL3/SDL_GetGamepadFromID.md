# SDL_GetGamepadFromID

Get the [SDL_Gamepad](SDL_Gamepad.html) associated with a joystick
instance ID, if it has been opened.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Gamepad * SDL_GetGamepadFromID(SDL_JoystickID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_JoystickID](SDL_JoystickID.html) | **instance_id** | the joystick instance ID of the gamepad. |

## Return Value

([SDL_Gamepad](SDL_Gamepad.html) \*) Returns an
[SDL_Gamepad](SDL_Gamepad.html) on success or NULL on failure or if it
hasn't been opened yet; call [SDL_GetError](SDL_GetError.html)() for
more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
