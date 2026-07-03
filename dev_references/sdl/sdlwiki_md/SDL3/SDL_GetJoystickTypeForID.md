# SDL_GetJoystickTypeForID

Get the type of a joystick, if available.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_JoystickType SDL_GetJoystickTypeForID(SDL_JoystickID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_JoystickID](SDL_JoystickID.html) | **instance_id** | the joystick instance ID. |

## Return Value

([SDL_JoystickType](SDL_JoystickType.html)) Returns the
[SDL_JoystickType](SDL_JoystickType.html) of the selected joystick. If
called with an invalid instance_id, this function returns
[`SDL_JOYSTICK_TYPE_UNKNOWN`](SDL_JOYSTICK_TYPE_UNKNOWN.html).

## Remarks

This can be called before any joysticks are opened.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetJoystickType](SDL_GetJoystickType.html)
- [SDL_GetJoysticks](SDL_GetJoysticks.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
