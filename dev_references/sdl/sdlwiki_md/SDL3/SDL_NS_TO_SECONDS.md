# SDL_NS_TO_SECONDS

Convert nanoseconds to seconds.

## Header File

Defined in
[\<SDL3/SDL_timer.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_timer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_NS_TO_SECONDS(NS)   ((NS) / SDL_NS_PER_SECOND)
```

</div>

## Macro Parameters

|        |                                       |
|--------|---------------------------------------|
| **NS** | the number of nanoseconds to convert. |

## Return Value

Returns NS, expressed in seconds.

## Remarks

This performs a division, so the results can be dramatically different
if `NS` is an integer or floating point value.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryTimer](CategoryTimer.html)
