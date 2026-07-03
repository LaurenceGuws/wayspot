# SDL_rand_bits

Generate 32 pseudo-random bits.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Uint32 SDL_rand_bits(void);
```

</div>

## Return Value

([Uint32](Uint32.html)) Returns a random value in the range of
\[0-[SDL_MAX_UINT32](SDL_MAX_UINT32.html)\].

## Remarks

You likely want to use [SDL_rand](SDL_rand.html)() to get a
psuedo-random number instead.

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

- [SDL_rand](SDL_rand.html)
- [SDL_randf](SDL_randf.html)
- [SDL_srand](SDL_srand.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
