# SDL_HINT_MOUSE_TOUCH_EVENTS

A variable controlling whether mouse events should generate synthetic
touch events.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_MOUSE_TOUCH_EVENTS "SDL_MOUSE_TOUCH_EVENTS"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": Mouse events will not generate touch events. (default for desktop
  platforms)
- "1": Mouse events will generate touch events. (default for mobile
  platforms, such as Android and iOS)

This hint can be set anytime.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
