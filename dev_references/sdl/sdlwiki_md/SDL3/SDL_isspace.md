# SDL_isspace

Report if a character is whitespace.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_isspace(int x);
```

</div>

## Function Parameters

|     |       |                           |
|-----|-------|---------------------------|
| int | **x** | character value to check. |

## Return Value

(int) Returns non-zero if x falls within the character class, zero
otherwise.

## Remarks

**WARNING**: Regardless of system locale, this will only treat the
following ASCII values as true:

- space (0x20)
- tab (0x09)
- newline (0x0A)
- vertical tab (0x0B)
- form feed (0x0C)
- return (0x0D)

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
