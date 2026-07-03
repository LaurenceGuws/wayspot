# SDL_GetGamepadName

Get the implementation-dependent name for an opened gamepad.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetGamepadName(SDL_Gamepad *gamepad);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | a gamepad identifier previously returned by [SDL_OpenGamepad](SDL_OpenGamepad.html)(). |

## Return Value

(const char \*) Returns the implementation dependent name for the
gamepad, or NULL if there is no name or the identifier passed is
invalid.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetGamepadNameForID](SDL_GetGamepadNameForID.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
