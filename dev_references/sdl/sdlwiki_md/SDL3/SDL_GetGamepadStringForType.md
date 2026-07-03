# SDL_GetGamepadStringForType

Convert from an [SDL_GamepadType](SDL_GamepadType.html) enum to a
string.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetGamepadStringForType(SDL_GamepadType type);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GamepadType](SDL_GamepadType.html) | **type** | an enum value for a given [SDL_GamepadType](SDL_GamepadType.html). |

## Return Value

(const char \*) Returns a string for the given type, or NULL if an
invalid type is specified. The string returned is of the format used by
[SDL_Gamepad](SDL_Gamepad.html) mapping strings.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetGamepadTypeFromString](SDL_GetGamepadTypeFromString.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
