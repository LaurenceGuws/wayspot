# SDL_GetGamepadType

Get the type of an opened gamepad.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GamepadType SDL_GetGamepadType(SDL_Gamepad *gamepad);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | the gamepad object to query. |

## Return Value

([SDL_GamepadType](SDL_GamepadType.html)) Returns the gamepad type, or
[SDL_GAMEPAD_TYPE_UNKNOWN](SDL_GAMEPAD_TYPE_UNKNOWN.html) if it's not
available.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetGamepadTypeForID](SDL_GetGamepadTypeForID.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
