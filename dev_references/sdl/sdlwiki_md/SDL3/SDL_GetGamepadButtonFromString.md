# SDL_GetGamepadButtonFromString

Convert a string into an [SDL_GamepadButton](SDL_GamepadButton.html)
enum.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GamepadButton SDL_GetGamepadButtonFromString(const char *str);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **str** | string representing a [SDL_Gamepad](SDL_Gamepad.html) button. |

## Return Value

([SDL_GamepadButton](SDL_GamepadButton.html)) Returns the
[SDL_GamepadButton](SDL_GamepadButton.html) enum corresponding to the
input string, or
[`SDL_GAMEPAD_BUTTON_INVALID`](SDL_GAMEPAD_BUTTON_INVALID.html) if no
match was found.

## Remarks

This function is called internally to translate
[SDL_Gamepad](SDL_Gamepad.html) mapping strings for the underlying
joystick device into the consistent [SDL_Gamepad](SDL_Gamepad.html)
mapping. You do not normally need to call this function unless you are
parsing [SDL_Gamepad](SDL_Gamepad.html) mappings in your own code.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetGamepadStringForButton](SDL_GetGamepadStringForButton.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
