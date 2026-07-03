# SDL_PumpEvents

Pump the event loop, gathering events from the input devices.

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_PumpEvents(void);
```

</div>

## Remarks

This function updates the event queue and internal input device state.

[SDL_PumpEvents](SDL_PumpEvents.html)() gathers all the pending input
information from devices and places it in the event queue. Without calls
to [SDL_PumpEvents](SDL_PumpEvents.html)() no events would ever be
placed on the queue. Often the need for calls to
[SDL_PumpEvents](SDL_PumpEvents.html)() is hidden from the user since
[SDL_PollEvent](SDL_PollEvent.html)() and
[SDL_WaitEvent](SDL_WaitEvent.html)() implicitly call
[SDL_PumpEvents](SDL_PumpEvents.html)(). However, if you are not polling
or waiting for events (e.g. you are filtering them), then you must call
[SDL_PumpEvents](SDL_PumpEvents.html)() to force an event queue update.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_PollEvent](SDL_PollEvent.html)
- [SDL_WaitEvent](SDL_WaitEvent.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryEvents](CategoryEvents.html)
