# SDL_GetJoystickFromPlayerIndex

Get the [SDL_Joystick](SDL_Joystick.html) associated with a player
index.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Joystick * SDL_GetJoystickFromPlayerIndex(int player_index);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| int | **player_index** | the player index to get the [SDL_Joystick](SDL_Joystick.html) for. |

## Return Value

([SDL_Joystick](SDL_Joystick.html) \*) Returns an
[SDL_Joystick](SDL_Joystick.html) on success or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetJoystickPlayerIndex](SDL_GetJoystickPlayerIndex.html)
- [SDL_SetJoystickPlayerIndex](SDL_SetJoystickPlayerIndex.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
