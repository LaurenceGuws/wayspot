# SDL_PeepEvents

Check the event queue for messages and optionally return them.

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_PeepEvents(SDL_Event *events, int numevents, SDL_EventAction action, Uint32 minType, Uint32 maxType);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Event](SDL_Event.html) \* | **events** | destination buffer for the retrieved events, may be NULL to leave the events in the queue and return the number of events that would have been stored. |
| int | **numevents** | if action is [SDL_ADDEVENT](SDL_ADDEVENT.html), the number of events to add back to the event queue; if action is [SDL_PEEKEVENT](SDL_PEEKEVENT.html) or [SDL_GETEVENT](SDL_GETEVENT.html), the maximum number of events to retrieve. |
| [SDL_EventAction](SDL_EventAction.html) | **action** | action to take; see [Remarks](#remarks) for details. |
| [Uint32](Uint32.html) | **minType** | minimum value of the event type to be considered; [SDL_EVENT_FIRST](SDL_EVENT_FIRST.html) is a safe choice. |
| [Uint32](Uint32.html) | **maxType** | maximum value of the event type to be considered; [SDL_EVENT_LAST](SDL_EVENT_LAST.html) is a safe choice. |

## Return Value

(int) Returns the number of events actually stored or -1 on failure;
call [SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

`action` may be any of the following:

- [`SDL_ADDEVENT`](SDL_ADDEVENT.html): up to `numevents` events will be
  added to the back of the event queue.
- [`SDL_PEEKEVENT`](SDL_PEEKEVENT.html): `numevents` events at the front
  of the event queue, within the specified minimum and maximum type,
  will be returned to the caller and will *not* be removed from the
  queue. If you pass NULL for `events`, then `numevents` is ignored and
  the total number of matching events will be returned.
- [`SDL_GETEVENT`](SDL_GETEVENT.html): up to `numevents` events at the
  front of the event queue, within the specified minimum and maximum
  type, will be returned to the caller and will be removed from the
  queue.

You may have to call [SDL_PumpEvents](SDL_PumpEvents.html)() before
calling this function. Otherwise, the events may not be ready to be
filtered when you call [SDL_PeepEvents](SDL_PeepEvents.html)().

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_PollEvent](SDL_PollEvent.html)
- [SDL_PumpEvents](SDL_PumpEvents.html)
- [SDL_PushEvent](SDL_PushEvent.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryEvents](CategoryEvents.html)
