# SDL_GetWindowFromEvent

Get window associated with an event.

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Window * SDL_GetWindowFromEvent(const SDL_Event *event);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const [SDL_Event](SDL_Event.html) \* | **event** | an event containing a `windowID`. |

## Return Value

([SDL_Window](SDL_Window.html) \*) Returns the associated window on
success or NULL if there is none.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_PollEvent](SDL_PollEvent.html)
- [SDL_WaitEvent](SDL_WaitEvent.html)
- [SDL_WaitEventTimeout](SDL_WaitEventTimeout.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryEvents](CategoryEvents.html)
