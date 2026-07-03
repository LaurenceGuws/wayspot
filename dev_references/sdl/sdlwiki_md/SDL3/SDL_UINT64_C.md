# SDL_UINT64_C

Append the 64 bit integer suffix to an unsigned integer literal.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_UINT64_C(c)  c ## ULL /* or whatever the current compiler uses. */
```

</div>

## Remarks

This helps compilers that might believe a integer literal larger than
0xFFFFFFFF is overflowing a 32-bit value. Use
`SDL_UINT64_C(0xFFFFFFFF1)` instead of `0xFFFFFFFF1` by itself.

## Version

This macro is available since SDL 3.2.0.

## See Also

- [SDL_SINT64_C](SDL_SINT64_C.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
