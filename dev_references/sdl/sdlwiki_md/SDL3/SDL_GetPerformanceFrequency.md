# SDL_GetPerformanceFrequency

Get the count per second of the high resolution counter.

## Header File

Defined in
[\<SDL3/SDL_timer.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_timer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Uint64 SDL_GetPerformanceFrequency(void);
```

</div>

## Return Value

([Uint64](Uint64.html)) Returns a platform-specific count per second.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetPerformanceCounter](SDL_GetPerformanceCounter.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTimer](CategoryTimer.html)
