# SDL_DelayNS

Wait a specified number of nanoseconds before returning.

## Header File

Defined in
[\<SDL3/SDL_timer.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_timer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DelayNS(Uint64 ns);
```

</div>

## Function Parameters

|                       |        |                                     |
|-----------------------|--------|-------------------------------------|
| [Uint64](Uint64.html) | **ns** | the number of nanoseconds to delay. |

## Remarks

This function waits a specified number of nanoseconds before returning.
It waits at least the specified time, but possibly longer due to OS
scheduling.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_Delay](SDL_Delay.html)
- [SDL_DelayPrecise](SDL_DelayPrecise.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTimer](CategoryTimer.html)
