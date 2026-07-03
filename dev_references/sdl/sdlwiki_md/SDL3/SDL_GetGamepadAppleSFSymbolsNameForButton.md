# SDL_GetGamepadAppleSFSymbolsNameForButton

Return the sfSymbolsName for a given button on a gamepad on Apple
platforms.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetGamepadAppleSFSymbolsNameForButton(SDL_Gamepad *gamepad, SDL_GamepadButton button);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | the gamepad to query. |
| [SDL_GamepadButton](SDL_GamepadButton.html) | **button** | a button on the gamepad. |

## Return Value

(const char \*) Returns the sfSymbolsName or NULL if the name can't be
found.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetGamepadAppleSFSymbolsNameForAxis](SDL_GetGamepadAppleSFSymbolsNameForAxis.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
