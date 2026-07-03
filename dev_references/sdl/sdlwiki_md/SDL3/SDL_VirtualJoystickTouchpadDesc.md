# SDL_VirtualJoystickTouchpadDesc

The structure that describes a virtual joystick touchpad.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_VirtualJoystickTouchpadDesc
{
    Uint16 nfingers;    /**< the number of simultaneous fingers on this touchpad */
    Uint16 padding[3];
} SDL_VirtualJoystickTouchpadDesc;
```

</div>

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_VirtualJoystickDesc](SDL_VirtualJoystickDesc.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryJoystick](CategoryJoystick.html)
