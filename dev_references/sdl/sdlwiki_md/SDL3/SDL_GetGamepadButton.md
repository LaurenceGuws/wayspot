# SDL_GetGamepadButton

Get the current state of a button on a gamepad.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetGamepadButton(SDL_Gamepad *gamepad, SDL_GamepadButton button);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | a gamepad. |
| [SDL_GamepadButton](SDL_GamepadButton.html) | **button** | a button index (one of the [SDL_GamepadButton](SDL_GamepadButton.html) values). |

## Return Value

(bool) Returns true if the button is pressed, false otherwise.

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
