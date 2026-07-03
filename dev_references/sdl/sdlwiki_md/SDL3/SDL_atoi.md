# SDL_atoi

Parse an `int` from a string.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_atoi(const char *str);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **str** | The null-terminated string to read. Must not be NULL. |

## Return Value

(int) Returns the parsed `int`.

## Remarks

The result of calling `SDL_atoi(str)` is equivalent to
`(int)SDL_strtol(str, NULL, 10)`.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_atof](SDL_atof.html)
- [SDL_strtol](SDL_strtol.html)
- [SDL_strtoul](SDL_strtoul.html)
- [SDL_strtoll](SDL_strtoll.html)
- [SDL_strtoull](SDL_strtoull.html)
- [SDL_strtod](SDL_strtod.html)
- [SDL_itoa](SDL_itoa.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
