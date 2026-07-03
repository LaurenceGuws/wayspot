# SDL_iconv_open

This function allocates a context for the specified character set
conversion.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_iconv_t SDL_iconv_open(const char *tocode,
                       const char *fromcode);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **tocode** | The target character encoding, must not be NULL. |
| const char \* | **fromcode** | The source character encoding, must not be NULL. |

## Return Value

([SDL_iconv_t](SDL_iconv_t.html)) Returns a handle that must be freed
with [SDL_iconv_close](SDL_iconv_close.html), or
[SDL_ICONV_ERROR](SDL_ICONV_ERROR.html) on failure.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_iconv](SDL_iconv.html)
- [SDL_iconv_close](SDL_iconv_close.html)
- [SDL_iconv_string](SDL_iconv_string.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
