# SDL_MS_TO_NS

Convert milliseconds to nanoseconds.

## Header File

Defined in
[\<SDL3/SDL_timer.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_timer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_MS_TO_NS(MS)        (((Uint64)(MS)) * SDL_NS_PER_MS)
```

</div>

## Macro Parameters

|        |                                        |
|--------|----------------------------------------|
| **MS** | the number of milliseconds to convert. |

## Return Value

Returns MS, expressed in nanoseconds.

## Remarks

This only converts whole numbers, not fractional milliseconds.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryTimer](CategoryTimer.html)
