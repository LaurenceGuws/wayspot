# SDL_AssertBreakpoint

The macro used when an assertion triggers a breakpoint.

## Header File

Defined in
[\<SDL3/SDL_assert.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_assert.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_AssertBreakpoint() SDL_TriggerBreakpoint()
```

</div>

## Remarks

This isn't for direct use by apps; use [SDL_assert](SDL_assert.html) or
[SDL_TriggerBreakpoint](SDL_TriggerBreakpoint.html) instead.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAssert](CategoryAssert.html)
