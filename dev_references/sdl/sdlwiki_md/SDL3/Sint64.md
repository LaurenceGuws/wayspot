# Sint64

A signed 64-bit integer type.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef int64_t Sint64;
#define SDL_MAX_SINT64  SDL_SINT64_C(0x7FFFFFFFFFFFFFFF)   /* 9223372036854775807 */
#define SDL_MIN_SINT64  ~SDL_SINT64_C(0x7FFFFFFFFFFFFFFF)  /* -9223372036854775808 */
```

</div>

## Version

This macro is available since SDL 3.2.0.

## See Also

- [SDL_SINT64_C](SDL_SINT64_C.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryStdinc](CategoryStdinc.html)
