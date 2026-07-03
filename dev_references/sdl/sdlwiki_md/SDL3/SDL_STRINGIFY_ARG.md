# SDL_STRINGIFY_ARG

Macro useful for building other macros with strings in them.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_STRINGIFY_ARG(arg)  #arg
```

</div>

## Macro Parameters

|         |                                         |
|---------|-----------------------------------------|
| **arg** | the text to turn into a string literal. |

## Remarks

For example:

<div id="cb2" class="sourceCode">

``` sourceCode
#define LOG_ERROR(X) OutputDebugString(SDL_STRINGIFY_ARG(__FUNCTION__) ": " X "\n")`
```

</div>

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
