# SDL_HINT_EMSCRIPTEN_ASYNCIFY

Disable giving back control to the browser automatically when running
with asyncify.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_EMSCRIPTEN_ASYNCIFY "SDL_EMSCRIPTEN_ASYNCIFY"
```

</div>

## Remarks

With -s ASYNCIFY, SDL calls emscripten_sleep during operations such as
refreshing the screen or polling events.

This hint only applies to the emscripten platform.

The variable can be set to the following values:

- "0": Disable emscripten_sleep calls (if you give back browser control
  manually or use asyncify for other purposes).
- "1": Enable emscripten_sleep calls. (default)

This hint can be set anytime.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
