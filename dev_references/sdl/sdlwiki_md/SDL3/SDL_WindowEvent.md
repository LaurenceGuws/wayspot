# SDL_WindowEvent

Window state change event data (event.window.\*)

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_WindowEvent
{
    SDL_EventType type; /**< SDL_EVENT_WINDOW_* */
    Uint32 reserved;
    Uint64 timestamp;   /**< In nanoseconds, populated using SDL_GetTicksNS() */
    SDL_WindowID windowID; /**< The associated window */
    Sint32 data1;       /**< event dependent data */
    Sint32 data2;       /**< event dependent data */
} SDL_WindowEvent;
```

</div>

## Version

This struct is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryEvents](CategoryEvents.html)
