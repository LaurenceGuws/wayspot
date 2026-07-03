# SDL_GetGamepadJoystick

Get the underlying joystick from a gamepad.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Joystick * SDL_GetGamepadJoystick(SDL_Gamepad *gamepad);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | the gamepad object that you want to get a joystick from. |

## Return Value

([SDL_Joystick](SDL_Joystick.html) \*) Returns an
[SDL_Joystick](SDL_Joystick.html) object, or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function will give you a [SDL_Joystick](SDL_Joystick.html) object,
which allows you to use the [SDL_Joystick](SDL_Joystick.html) functions
with a [SDL_Gamepad](SDL_Gamepad.html) object. This would be useful for
getting a joystick's position at any given time, even if it hasn't moved
(moving it would produce an event, which would have the axis' value).

The pointer returned is owned by the [SDL_Gamepad](SDL_Gamepad.html).
You should not call [SDL_CloseJoystick](SDL_CloseJoystick.html)() on it,
for example, since doing so will likely cause SDL to crash.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
