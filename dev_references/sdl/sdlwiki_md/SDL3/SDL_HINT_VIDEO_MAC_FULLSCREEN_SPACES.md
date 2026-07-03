# SDL_HINT_VIDEO_MAC_FULLSCREEN_SPACES

A variable that specifies the policy for fullscreen Spaces on macOS.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_VIDEO_MAC_FULLSCREEN_SPACES "SDL_VIDEO_MAC_FULLSCREEN_SPACES"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": Disable Spaces support (FULLSCREEN_DESKTOP won't use them and
  [SDL_WINDOW_RESIZABLE](SDL_WINDOW_RESIZABLE.html) windows won't offer
  the "fullscreen" button on their titlebars).
- "1": Enable Spaces support (FULLSCREEN_DESKTOP will use them and
  [SDL_WINDOW_RESIZABLE](SDL_WINDOW_RESIZABLE.html) windows will offer
  the "fullscreen" button on their titlebars). (default)

This hint should be set before creating a window.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
