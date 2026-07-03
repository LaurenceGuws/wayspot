# SDL_GamepadEventsEnabled

Query the state of gamepad event processing.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GamepadEventsEnabled(void);
```

</div>

## Return Value

(bool) Returns true if gamepad events are being processed, false
otherwise.

## Remarks

If gamepad events are disabled, you must call
[SDL_UpdateGamepads](SDL_UpdateGamepads.html)() yourself and check the
state of the gamepad when you want gamepad information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetGamepadEventsEnabled](SDL_SetGamepadEventsEnabled.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
