# SDL_GetGamepadStringForButton

Convert from an [SDL_GamepadButton](SDL_GamepadButton.html) enum to a
string.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetGamepadStringForButton(SDL_GamepadButton button);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GamepadButton](SDL_GamepadButton.html) | **button** | an enum value for a given [SDL_GamepadButton](SDL_GamepadButton.html). |

## Return Value

(const char \*) Returns a string for the given button, or NULL if an
invalid button is specified. The string returned is of the format used
by [SDL_Gamepad](SDL_Gamepad.html) mapping strings.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetGamepadButtonFromString](SDL_GetGamepadButtonFromString.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
