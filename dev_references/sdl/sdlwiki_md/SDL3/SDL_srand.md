# SDL_srand

Seeds the pseudo-random number generator.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_srand(Uint64 seed);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [Uint64](Uint64.html) | **seed** | the value to use as a random number seed, or 0 to use [SDL_GetPerformanceCounter](SDL_GetPerformanceCounter.html)(). |

## Remarks

Reusing the seed number will cause [SDL_rand](SDL_rand.html)() to repeat
the same stream of 'random' numbers.

## Thread Safety

This should be called on the same thread that calls
[SDL_rand](SDL_rand.html)()

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_rand](SDL_rand.html)
- [SDL_rand_bits](SDL_rand_bits.html)
- [SDL_randf](SDL_randf.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
