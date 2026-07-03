# Sint32

A signed 32-bit integer type.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef int32_t Sint32;
#define SDL_MAX_SINT32  ((Sint32)0x7FFFFFFF)    /* 2147483647 */
#define SDL_MIN_SINT32  ((Sint32)(~0x7FFFFFFF)) /* -2147483648 */
```

</div>

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryStdinc](CategoryStdinc.html)
