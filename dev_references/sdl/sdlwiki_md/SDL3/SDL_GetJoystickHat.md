# SDL_GetJoystickHat

Get the current state of a POV hat on a joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Uint8 SDL_GetJoystickHat(SDL_Joystick *joystick, int hat);


#define SDL_HAT_CENTERED    0x00u
#define SDL_HAT_UP          0x01u
#define SDL_HAT_RIGHT       0x02u
#define SDL_HAT_DOWN        0x04u
#define SDL_HAT_LEFT        0x08u
#define SDL_HAT_RIGHTUP     (SDL_HAT_RIGHT|SDL_HAT_UP)
#define SDL_HAT_RIGHTDOWN   (SDL_HAT_RIGHT|SDL_HAT_DOWN)
#define SDL_HAT_LEFTUP      (SDL_HAT_LEFT|SDL_HAT_UP)
#define SDL_HAT_LEFTDOWN    (SDL_HAT_LEFT|SDL_HAT_DOWN)
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Joystick](SDL_Joystick.html) \* | **joystick** | an [SDL_Joystick](SDL_Joystick.html) structure containing joystick information. |
| int | **hat** | the hat index to get the state from; indices start at index 0. |

## Return Value

(Uint8) Returns the current hat position.

## Remarks

The returned value will be one of the `SDL_HAT_*` values.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetNumJoystickHats](SDL_GetNumJoystickHats.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
