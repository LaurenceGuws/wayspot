# SDL_strtol

Parse a `long` from a string.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
long SDL_strtol(const char *str, char **endp, int base);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **str** | The null-terminated string to read. Must not be NULL. |
| char \*\* | **endp** | If not NULL, the address of the first invalid character (i.e. the next character after the parsed number) will be written to this pointer. |
| int | **base** | The base of the integer to read. Supported values are 0 and 2 to 36 inclusive. If 0, the base will be inferred from the number's prefix (0x for hexadecimal, 0 for octal, decimal otherwise). |

## Return Value

(long) Returns the parsed `long`, or 0 if no number could be parsed.

## Remarks

If `str` starts with whitespace, then those whitespace characters are
skipped before attempting to parse the number.

If the parsed number does not fit inside a `long`, the result is clamped
to the minimum and maximum representable `long` values.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_atoi](SDL_atoi.html)
- [SDL_atof](SDL_atof.html)
- [SDL_strtoul](SDL_strtoul.html)
- [SDL_strtoll](SDL_strtoll.html)
- [SDL_strtoull](SDL_strtoull.html)
- [SDL_strtod](SDL_strtod.html)
- [SDL_ltoa](SDL_ltoa.html)
- [SDL_wcstol](SDL_wcstol.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
