# SDL_SetEventEnabled

Set the state of processing events by type.

## Header File

Defined in
[\<SDL3/SDL_events.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_events.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_SetEventEnabled(Uint32 type, bool enabled);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [Uint32](Uint32.html) | **type** | the type of event; see [SDL_EventType](SDL_EventType.html) for details. |
| bool | **enabled** | whether to process the event or not. |

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_EventEnabled](SDL_EventEnabled.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryEvents](CategoryEvents.html)
