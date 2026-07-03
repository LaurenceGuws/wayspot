# SDL_HINT_VIDEO_METAL_AUTO_RESIZE_DRAWABLE

A variable indicating whether the metal layer drawable size should be
updated for the
[SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED](SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED.html)
event on macOS.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_VIDEO_METAL_AUTO_RESIZE_DRAWABLE "SDL_VIDEO_METAL_AUTO_RESIZE_DRAWABLE"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": the metal layer drawable size will not be updated on the
  [SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED](SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED.html)
  event.
- "1": the metal layer drawable size will be updated on the
  [SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED](SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED.html)
  event. (default)

This hint should be set before
[SDL_Metal_CreateView](SDL_Metal_CreateView.html) called.

## Version

This hint is available since SDL 3.4.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
