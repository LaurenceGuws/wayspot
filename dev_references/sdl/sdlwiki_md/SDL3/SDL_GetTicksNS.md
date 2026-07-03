# SDL_GetTicksNS

Get the number of nanoseconds since SDL library initialization.

## Header File

Defined in
[\<SDL3/SDL_timer.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_timer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Uint64 SDL_GetTicksNS(void);
```

</div>

## Return Value

([Uint64](Uint64.html)) Returns an unsigned 64-bit value representing
the number of nanoseconds since the SDL library initialized.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTimer](CategoryTimer.html)
