# SDL_FlushEvents

Clear events of a range of types from the event queue.

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_FlushEvents(Uint32 minType, Uint32 maxType);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [Uint32](Uint32.html) | **minType** | the low end of event type to be cleared, inclusive; see [SDL_EventType](SDL_EventType.html) for details. |
| [Uint32](Uint32.html) | **maxType** | the high end of event type to be cleared, inclusive; see [SDL_EventType](SDL_EventType.html) for details. |

## Remarks

This will unconditionally remove any events from the queue that are in
the range of `minType` to `maxType`, inclusive. If you need to remove a
single event type, use [SDL_FlushEvent](SDL_FlushEvent.html)() instead.

It's also normal to just ignore events you don't care about in your
event loop without calling this function.

This function only affects currently queued events. If you want to make
sure that all pending OS events are flushed, you can call
[SDL_PumpEvents](SDL_PumpEvents.html)() on the main thread immediately
before the flush call.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_FlushEvent](SDL_FlushEvent.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryEvents](CategoryEvents.html)
