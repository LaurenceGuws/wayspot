# SDL_GetJoysticks

Get a list of currently connected joysticks.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_JoystickID * SDL_GetJoysticks(int *count);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| int \* | **count** | a pointer filled in with the number of joysticks returned, may be NULL. |

## Return Value

([SDL_JoystickID](SDL_JoystickID.html) \*) Returns a 0 terminated array
of joystick instance IDs or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information. This should be
freed with [SDL_free](SDL_free.html)() when it is no longer needed.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_HasJoystick](SDL_HasJoystick.html)
- [SDL_OpenJoystick](SDL_OpenJoystick.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
