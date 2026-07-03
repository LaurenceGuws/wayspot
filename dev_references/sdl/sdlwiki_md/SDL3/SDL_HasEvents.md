# SDL_HasEvents

Check for the existence of certain event types in the event queue.

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_HasEvents(Uint32 minType, Uint32 maxType);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [Uint32](Uint32.html) | **minType** | the low end of event type to be queried, inclusive; see [SDL_EventType](SDL_EventType.html) for details. |
| [Uint32](Uint32.html) | **maxType** | the high end of event type to be queried, inclusive; see [SDL_EventType](SDL_EventType.html) for details. |

## Return Value

(bool) Returns true if events with type \>= `minType` and \<= `maxType`
are present, or false if not.

## Remarks

If you need to check for a single event type, use
[SDL_HasEvent](SDL_HasEvent.html)() instead.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_HasEvents](SDL_HasEvents.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryEvents](CategoryEvents.html)
