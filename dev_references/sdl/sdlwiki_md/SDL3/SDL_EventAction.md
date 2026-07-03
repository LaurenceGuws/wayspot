# SDL_EventAction

The type of action to request from
[SDL_PeepEvents](SDL_PeepEvents.html)().

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_EventAction
{
    SDL_ADDEVENT,  /**< Add events to the back of the queue. */
    SDL_PEEKEVENT, /**< Check but don't remove events from the queue front. */
    SDL_GETEVENT   /**< Retrieve/remove events from the front of the queue. */
} SDL_EventAction;
```

</div>

## Version

This enum is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html),
[CategoryEvents](CategoryEvents.html)
