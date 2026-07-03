# SDL_GetJoystickPlayerIndex

Get the player index of an opened joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetJoystickPlayerIndex(SDL_Joystick *joystick);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Joystick](SDL_Joystick.html) \* | **joystick** | the [SDL_Joystick](SDL_Joystick.html) obtained from [SDL_OpenJoystick](SDL_OpenJoystick.html)(). |

## Return Value

(int) Returns the player index, or -1 if it's not available.

## Remarks

For XInput controllers this returns the XInput user index. Many
joysticks will not be able to supply this information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetJoystickPlayerIndex](SDL_SetJoystickPlayerIndex.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
