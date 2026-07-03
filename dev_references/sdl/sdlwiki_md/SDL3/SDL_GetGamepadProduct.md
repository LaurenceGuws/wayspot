# SDL_GetGamepadProduct

Get the USB product ID of an opened gamepad, if available.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Uint16 SDL_GetGamepadProduct(SDL_Gamepad *gamepad);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | the gamepad object to query. |

## Return Value

([Uint16](Uint16.html)) Returns the USB product ID, or zero if
unavailable.

## Remarks

If the product ID isn't available this function returns 0.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetGamepadProductForID](SDL_GetGamepadProductForID.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
