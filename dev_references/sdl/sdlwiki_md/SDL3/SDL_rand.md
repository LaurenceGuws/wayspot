# SDL_rand

Generate a pseudo-random number less than n for positive n

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Sint32 SDL_rand(Sint32 n);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [Sint32](Sint32.html) | **n** | the number of possible outcomes. n must be positive. |

## Return Value

([Sint32](Sint32.html)) Returns a random value in the range of \[0 ..
n-1\].

## Remarks

The method used is faster and of better quality than `rand() % n`. Odds
are roughly 99.9% even for n = 1 million. Evenness is better for smaller
n, and much worse as n gets bigger.

Example: to simulate a d6 use `SDL_rand(6) + 1` The +1 converts 0..5 to
1..6

If you want to generate a pseudo-random number in the full range of
[Sint32](Sint32.html), you should use:
([Sint32](Sint32.html))[SDL_rand_bits](SDL_rand_bits.html)()

If you want reproducible output, be sure to initialize with
[SDL_srand](SDL_srand.html)() first.

There are no guarantees as to the quality of the random sequence
produced, and this should not be used for security (cryptography,
passwords) or where money is on the line (loot-boxes, casinos). There
are many random number libraries available with different
characteristics and you should pick one of those to meet any serious
needs.

## Thread Safety

All calls should be made from a single thread

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_srand](SDL_srand.html)
- [SDL_randf](SDL_randf.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
