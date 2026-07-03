# SDL_DetachVirtualJoystick

Detach a virtual joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_DetachVirtualJoystick(SDL_JoystickID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_JoystickID](SDL_JoystickID.html) | **instance_id** | the joystick instance ID, previously returned from [SDL_AttachVirtualJoystick](SDL_AttachVirtualJoystick.html)(). |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_AttachVirtualJoystick](SDL_AttachVirtualJoystick.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
