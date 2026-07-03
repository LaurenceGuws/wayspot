# SDL_GetGamepadFromPlayerIndex

Get the [SDL_Gamepad](SDL_Gamepad.html) associated with a player index.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Gamepad * SDL_GetGamepadFromPlayerIndex(int player_index);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| int | **player_index** | the player index, which different from the instance ID. |

## Return Value

([SDL_Gamepad](SDL_Gamepad.html) \*) Returns the
[SDL_Gamepad](SDL_Gamepad.html) associated with a player index.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetGamepadPlayerIndex](SDL_GetGamepadPlayerIndex.html)
- [SDL_SetGamepadPlayerIndex](SDL_SetGamepadPlayerIndex.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
