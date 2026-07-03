# SDL_GetGamepadAxis

Get the current state of an axis control on a gamepad.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Sint16 SDL_GetGamepadAxis(SDL_Gamepad *gamepad, SDL_GamepadAxis axis);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | a gamepad. |
| [SDL_GamepadAxis](SDL_GamepadAxis.html) | **axis** | an axis index (one of the [SDL_GamepadAxis](SDL_GamepadAxis.html) values). |

## Return Value

([Sint16](Sint16.html)) Returns axis state.

## Remarks

The axis indices start at index 0.

For thumbsticks, the state is a value ranging from -32768 (up/left) to
32767 (down/right).

Triggers range from 0 when released to 32767 when fully pressed, and
never return a negative value. Note that this differs from the value
reported by the lower-level
[SDL_GetJoystickAxis](SDL_GetJoystickAxis.html)(), which normally uses
the full range.

Note that for invalid gamepads or axes, this will return 0. Zero is also
a valid value in normal operation; usually it means a centered axis.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GamepadHasAxis](SDL_GamepadHasAxis.html)
- [SDL_GetGamepadButton](SDL_GetGamepadButton.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
