# SDL_HintCallback

A callback used to send notifications of hint value changes.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef void(SDLCALL *SDL_HintCallback)(void *userdata, const char *name, const char *oldValue, const char *newValue);
```

</div>

## Function Parameters

|  |  |
|----|----|
| **userdata** | what was passed as `userdata` to [SDL_AddHintCallback](SDL_AddHintCallback.html)(). |
| **name** | what was passed as `name` to [SDL_AddHintCallback](SDL_AddHintCallback.html)(). |
| **oldValue** | the previous hint value. |
| **newValue** | the new value hint is to be set to. |

## Remarks

This is called an initial time during
[SDL_AddHintCallback](SDL_AddHintCallback.html) with the hint's current
value, and then again each time the hint's value changes. In the initial
call, the current value is in both `oldValue` and `newValue`.

## Thread Safety

This callback is fired from whatever thread is setting a new hint value.
SDL holds a lock on the hint subsystem when calling this callback.

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_AddHintCallback](SDL_AddHintCallback.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryHints](CategoryHints.html)
