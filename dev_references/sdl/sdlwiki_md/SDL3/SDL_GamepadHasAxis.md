# SDL_GamepadHasAxis

Query whether a gamepad has a given axis.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GamepadHasAxis(SDL_Gamepad *gamepad, SDL_GamepadAxis axis);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | a gamepad. |
| [SDL_GamepadAxis](SDL_GamepadAxis.html) | **axis** | an axis enum value (an [SDL_GamepadAxis](SDL_GamepadAxis.html) value). |

## Return Value

(bool) Returns true if the gamepad has this axis, false otherwise.

## Remarks

This merely reports whether the gamepad's mapping defined this axis, as
that is all the information SDL has about the physical device.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GamepadHasButton](SDL_GamepadHasButton.html)
- [SDL_GetGamepadAxis](SDL_GetGamepadAxis.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
