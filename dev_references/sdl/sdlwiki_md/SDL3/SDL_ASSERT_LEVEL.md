# SDL_ASSERT_LEVEL

The level of assertion aggressiveness.

## Header File

Defined in
[\<SDL3/SDL_assert.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_assert.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_ASSERT_LEVEL SomeNumberBasedOnVariousFactors
```

</div>

## Remarks

This value changes depending on compiler options and other preprocessor
defines.

It is currently one of the following values, but future SDL releases
might add more:

- 0: All SDL assertion macros are disabled.
- 1: Release settings: [SDL_assert](SDL_assert.html) disabled,
  [SDL_assert_release](SDL_assert_release.html) enabled.
- 2: Debug settings: [SDL_assert](SDL_assert.html) and
  [SDL_assert_release](SDL_assert_release.html) enabled.
- 3: Paranoid settings: All SDL assertion macros enabled, including
  [SDL_assert_paranoid](SDL_assert_paranoid.html).

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAssert](CategoryAssert.html)
