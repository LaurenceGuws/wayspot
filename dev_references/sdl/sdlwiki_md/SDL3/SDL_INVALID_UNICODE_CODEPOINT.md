# SDL_INVALID_UNICODE_CODEPOINT

The Unicode REPLACEMENT CHARACTER codepoint.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_INVALID_UNICODE_CODEPOINT 0xFFFD
```

</div>

## Remarks

[SDL_StepUTF8](SDL_StepUTF8.html)() and
[SDL_StepBackUTF8](SDL_StepBackUTF8.html)() report this codepoint when
they encounter a UTF-8 string with encoding errors.

This tends to render as something like a question mark in most places.

## Version

This macro is available since SDL 3.2.0.

## See Also

- [SDL_StepBackUTF8](SDL_StepBackUTF8.html)
- [SDL_StepUTF8](SDL_StepUTF8.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryStdinc](CategoryStdinc.html)
