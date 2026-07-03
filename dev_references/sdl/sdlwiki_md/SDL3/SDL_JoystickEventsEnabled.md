# SDL_JoystickEventsEnabled

Query the state of joystick event processing.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_JoystickEventsEnabled(void);
```

</div>

## Return Value

(bool) Returns true if joystick events are being processed, false
otherwise.

## Remarks

If joystick events are disabled, you must call
[SDL_UpdateJoysticks](SDL_UpdateJoysticks.html)() yourself and check the
state of the joystick when you want joystick information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetJoystickEventsEnabled](SDL_SetJoystickEventsEnabled.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
