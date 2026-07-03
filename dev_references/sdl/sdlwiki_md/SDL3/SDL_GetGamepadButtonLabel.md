# SDL_GetGamepadButtonLabel

Get the label of a button on a gamepad.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GamepadButtonLabel SDL_GetGamepadButtonLabel(SDL_Gamepad *gamepad, SDL_GamepadButton button);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | a gamepad. |
| [SDL_GamepadButton](SDL_GamepadButton.html) | **button** | a button index (one of the [SDL_GamepadButton](SDL_GamepadButton.html) values). |

## Return Value

([SDL_GamepadButtonLabel](SDL_GamepadButtonLabel.html)) Returns the
[SDL_GamepadButtonLabel](SDL_GamepadButtonLabel.html) enum corresponding
to the button label.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetGamepadButtonLabelForType](SDL_GetGamepadButtonLabelForType.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
