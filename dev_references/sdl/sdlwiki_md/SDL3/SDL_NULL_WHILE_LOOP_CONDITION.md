# SDL_NULL_WHILE_LOOP_CONDITION

A macro for wrapping code in `do {} while (0);` without compiler
warnings.

## Header File

Defined in
[\<SDL3/SDL_assert.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_assert.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_NULL_WHILE_LOOP_CONDITION (0)
```

</div>

## Remarks

Visual Studio with really aggressive warnings enabled needs this to
avoid compiler complaints.

the `do {} while (0);` trick is useful for wrapping code in a macro that
may or may not be a single statement, to avoid various C language
accidents.

To use:

<div id="cb2" class="sourceCode">

``` sourceCode
do { SomethingOnce(); } while (SDL_NULL_WHILE_LOOP_CONDITION (0));
```

</div>

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAssert](CategoryAssert.html)
