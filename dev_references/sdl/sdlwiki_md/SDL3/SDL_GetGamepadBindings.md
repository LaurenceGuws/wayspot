# SDL_GetGamepadBindings

Get the SDL joystick layer bindings for a gamepad.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GamepadBinding ** SDL_GetGamepadBindings(SDL_Gamepad *gamepad, int *count);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | a gamepad. |
| int \* | **count** | a pointer filled in with the number of bindings returned. |

## Return Value

([SDL_GamepadBinding](SDL_GamepadBinding.html) \*\*) Returns a NULL
terminated array of pointers to bindings or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information. This is a
single allocation that should be freed with [SDL_free](SDL_free.html)()
when it is no longer needed.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
