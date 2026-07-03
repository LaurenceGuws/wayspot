# SDL_ClipboardEvent

An event triggered when the clipboard contents have changed
(event.clipboard.\*)

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_ClipboardEvent
{
    SDL_EventType type; /**< SDL_EVENT_CLIPBOARD_UPDATE */
    Uint32 reserved;
    Uint64 timestamp;   /**< In nanoseconds, populated using SDL_GetTicksNS() */
    bool owner;         /**< are we owning the clipboard (internal update) */
    Sint32 num_mime_types;   /**< number of mime types */
    const char **mime_types; /**< current mime types */
} SDL_ClipboardEvent;
```

</div>

## Version

This struct is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryEvents](CategoryEvents.html)
