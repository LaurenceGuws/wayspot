# SDL_iconv_wchar_utf8

Convert a wchar_t string to UTF-8.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_iconv_wchar_utf8(S)     SDL_iconv_string("UTF-8", "WCHAR_T", SDL_reinterpret_cast(const char *, S), (SDL_wcslen(S)+1)*sizeof(wchar_t))
```

</div>

## Macro Parameters

|       |                        |
|-------|------------------------|
| **S** | the string to convert. |

## Return Value

Returns a new string, converted to the new encoding, or NULL on error.

## Remarks

This is a helper macro that might be more clear than calling
[SDL_iconv_string](SDL_iconv_string.html) directly. However, it
double-evaluates its parameter, so do not use an expression with
side-effects here.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
