# SDL_ispunct

Report if a character is a punctuation mark.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_ispunct(int x);
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

**WARNING**: Regardless of system locale, this is equivalent to
`((SDL_isgraph(x)) && (!SDL_isalnum(x)))`.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_isgraph](SDL_isgraph.html)
- [SDL_isalnum](SDL_isalnum.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStdinc](CategoryStdinc.html)
