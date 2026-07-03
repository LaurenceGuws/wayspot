# SDL_FLOATWORDORDER

A macro that reports the target system's floating point word order.

## Header File

Defined in
[\<SDL3/SDL_endian.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_endian.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_FLOATWORDORDER   SDL_LIL_ENDIAN___or_maybe___SDL_BIG_ENDIAN
```

</div>

## Remarks

This is set to either [SDL_LIL_ENDIAN](SDL_LIL_ENDIAN.html) or
[SDL_BIG_ENDIAN](SDL_BIG_ENDIAN.html) (and maybe other values in the
future, if something else becomes popular). This can be tested with the
preprocessor, so decisions can be made at compile time.

<div id="cb2" class="sourceCode">

``` sourceCode
#if SDL_FLOATWORDORDER == SDL_BIG_ENDIAN
SDL_Log("This system's floats are bigendian.");
#endif
```

</div>

## Version

This macro is available since SDL 3.2.0.

## See Also

- [SDL_LIL_ENDIAN](SDL_LIL_ENDIAN.html)
- [SDL_BIG_ENDIAN](SDL_BIG_ENDIAN.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryEndian](CategoryEndian.html)
