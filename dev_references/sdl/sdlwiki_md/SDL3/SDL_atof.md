# SDL_atof

Parse a `double` from a string.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
double SDL_atof(const char *str);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **str** | The null-terminated string to read. Must not be NULL. |

## Return Value

(double) Returns the parsed `double`.

## Remarks

The result of calling `SDL_atof(str)` is equivalent to
`SDL_strtod(str, NULL)`.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_atoi](SDL_atoi.html)
- [SDL_strtol](SDL_strtol.html)
- [SDL_strtoul](SDL_strtoul.html)
- [SDL_strtoll](SDL_strtoll.html)
- [SDL_strtoull](SDL_strtoull.html)
- [SDL_strtod](SDL_strtod.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
