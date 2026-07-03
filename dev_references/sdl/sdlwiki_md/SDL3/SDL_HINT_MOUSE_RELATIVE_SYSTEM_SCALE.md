# SDL_HINT_MOUSE_RELATIVE_SYSTEM_SCALE

A variable controlling whether the system mouse acceleration curve is
used for relative mouse motion.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_MOUSE_RELATIVE_SYSTEM_SCALE "SDL_MOUSE_RELATIVE_SYSTEM_SCALE"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": Relative mouse motion will be unscaled. (default)
- "1": Relative mouse motion will be scaled using the system mouse
  acceleration curve.

If
[SDL_HINT_MOUSE_RELATIVE_SPEED_SCALE](SDL_HINT_MOUSE_RELATIVE_SPEED_SCALE.html)
is set, that will be applied after system speed scale.

This hint can be set anytime.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
