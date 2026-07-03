# SDL_GamepadHasButton

Query whether a gamepad has a given button.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GamepadHasButton(SDL_Gamepad *gamepad, SDL_GamepadButton button);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | a gamepad. |
| [SDL_GamepadButton](SDL_GamepadButton.html) | **button** | a button enum value (an [SDL_GamepadButton](SDL_GamepadButton.html) value). |

## Return Value

(bool) Returns true if the gamepad has this button, false otherwise.

## Remarks

This merely reports whether the gamepad's mapping defined this button,
as that is all the information SDL has about the physical device.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GamepadHasAxis](SDL_GamepadHasAxis.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
