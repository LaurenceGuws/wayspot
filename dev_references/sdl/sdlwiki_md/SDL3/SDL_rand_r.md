# SDL_rand_r

Generate a pseudo-random number less than n for positive n

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Sint32 SDL_rand_r(Uint64 *state, Sint32 n);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [Uint64](Uint64.html) \* | **state** | a pointer to the current random number state, this may not be NULL. |
| [Sint32](Sint32.html) | **n** | the number of possible outcomes. n must be positive. |

## Return Value

([Sint32](Sint32.html)) Returns a random value in the range of \[0 ..
n-1\].

## Remarks

The method used is faster and of better quality than `rand() % n`. Odds
are roughly 99.9% even for n = 1 million. Evenness is better for smaller
n, and much worse as n gets bigger.

Example: to simulate a d6 use `SDL_rand_r(state, 6) + 1` The +1 converts
0..5 to 1..6

If you want to generate a pseudo-random number in the full range of
[Sint32](Sint32.html), you should use:
([Sint32](Sint32.html))[SDL_rand_bits_r](SDL_rand_bits_r.html)(state)

There are no guarantees as to the quality of the random sequence
produced, and this should not be used for security (cryptography,
passwords) or where money is on the line (loot-boxes, casinos). There
are many random number libraries available with different
characteristics and you should pick one of those to meet any serious
needs.

## Thread Safety

This function is thread-safe, as long as the state pointer isn't shared
between threads.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_rand](SDL_rand.html)
- [SDL_rand_bits_r](SDL_rand_bits_r.html)
- [SDL_randf_r](SDL_randf_r.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
