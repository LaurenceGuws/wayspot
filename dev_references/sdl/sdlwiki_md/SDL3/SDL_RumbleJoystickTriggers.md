# SDL_RumbleJoystickTriggers

Start a rumble effect in the joystick's triggers.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RumbleJoystickTriggers(SDL_Joystick *joystick, Uint16 left_rumble, Uint16 right_rumble, Uint32 duration_ms);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Joystick](SDL_Joystick.html) \* | **joystick** | the joystick to vibrate. |
| [Uint16](Uint16.html) | **left_rumble** | the intensity of the left trigger rumble motor, from 0 to 0xFFFF. |
| [Uint16](Uint16.html) | **right_rumble** | the intensity of the right trigger rumble motor, from 0 to 0xFFFF. |
| [Uint32](Uint32.html) | **duration_ms** | the duration of the rumble effect, in milliseconds. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Each call to this function cancels any previous trigger rumble effect,
and calling it with 0 intensity stops any rumbling.

Note that this is rumbling of the *triggers* and not the game controller
as a whole. This is currently only supported on Xbox One controllers. If
you want the (more common) whole-controller rumble, use
[SDL_RumbleJoystick](SDL_RumbleJoystick.html)() instead.

This function requires you to process SDL events or call
[SDL_UpdateJoysticks](SDL_UpdateJoysticks.html)() to update rumble
state.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_RumbleJoystick](SDL_RumbleJoystick.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
