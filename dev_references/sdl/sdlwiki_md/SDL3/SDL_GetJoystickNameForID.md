# SDL_GetJoystickNameForID

Get the implementation dependent name of a joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetJoystickNameForID(SDL_JoystickID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_JoystickID](SDL_JoystickID.html) | **instance_id** | the joystick instance ID. |

## Return Value

(const char \*) Returns the name of the selected joystick. If no name
can be found, this function returns NULL; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This can be called before any joysticks are opened.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetJoystickName](SDL_GetJoystickName.html)
- [SDL_GetJoysticks](SDL_GetJoysticks.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
