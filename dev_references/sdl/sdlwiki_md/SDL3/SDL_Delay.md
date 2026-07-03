# SDL_Delay

Wait a specified number of milliseconds before returning.

## Header File

Defined in
[\<SDL3/SDL_timer.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_timer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_Delay(Uint32 ms);
```

</div>

## Function Parameters

|                       |        |                                      |
|-----------------------|--------|--------------------------------------|
| [Uint32](Uint32.html) | **ms** | the number of milliseconds to delay. |

## Remarks

This function waits a specified number of milliseconds before returning.
It waits at least the specified time, but possibly longer due to OS
scheduling.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_DelayNS](SDL_DelayNS.html)
- [SDL_DelayPrecise](SDL_DelayPrecise.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTimer](CategoryTimer.html)
