# SDL_WaitEvent

Wait indefinitely for the next available event.

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_WaitEvent(SDL_Event *event);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Event](SDL_Event.html) \* | **event** | the [SDL_Event](SDL_Event.html) structure to be filled in with the next event from the queue, or NULL. |

## Return Value

(bool) Returns true on success or false if there was an error while
waiting for events; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Remarks

If `event` is not NULL, the next event is removed from the queue and
stored in the [SDL_Event](SDL_Event.html) structure pointed to by
`event`.

As this function may implicitly call
[SDL_PumpEvents](SDL_PumpEvents.html)(), you can only call this function
in the thread that initialized the video subsystem.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_PollEvent](SDL_PollEvent.html)
- [SDL_PushEvent](SDL_PushEvent.html)
- [SDL_WaitEventTimeout](SDL_WaitEventTimeout.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryEvents](CategoryEvents.html)
