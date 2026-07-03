# SDL_PushEvent

Add an event to the event queue.

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_PushEvent(SDL_Event *event);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Event](SDL_Event.html) \* | **event** | the [SDL_Event](SDL_Event.html) to be added to the queue. |

## Return Value

(bool) Returns true on success, false if the event was filtered or on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.
A common reason for error is the event queue being full.

## Remarks

The event queue can actually be used as a two way communication channel.
Not only can events be read from the queue, but the user can also push
their own events onto it. `event` is a pointer to the event structure
you wish to push onto the queue. The event is copied into the queue, and
the caller may dispose of the memory pointed to after
[SDL_PushEvent](SDL_PushEvent.html)() returns.

Note: Pushing device input events onto the queue doesn't modify the
state of the device within SDL.

Note: Events pushed onto the queue with
[SDL_PushEvent](SDL_PushEvent.html)() get passed through the event
filter but events added with [SDL_PeepEvents](SDL_PeepEvents.html)() do
not.

For pushing application-specific events, please use
[SDL_RegisterEvents](SDL_RegisterEvents.html)() to get an event type
that does not conflict with other code that also wants its own custom
event types.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_PeepEvents](SDL_PeepEvents.html)
- [SDL_PollEvent](SDL_PollEvent.html)
- [SDL_RegisterEvents](SDL_RegisterEvents.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryEvents](CategoryEvents.html)
