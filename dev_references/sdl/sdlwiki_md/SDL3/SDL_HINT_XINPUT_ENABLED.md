# SDL_HINT_XINPUT_ENABLED

A variable controlling whether XInput should be used for controller
handling.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_XINPUT_ENABLED "SDL_XINPUT_ENABLED"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": XInput is not enabled.
- "1": XInput is enabled. (default)

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
