# SDL_HINT_VIDEO_EGL_ALLOW_GETDISPLAY_FALLBACK

If eglGetPlatformDisplay fails, fall back to calling eglGetDisplay.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_VIDEO_EGL_ALLOW_GETDISPLAY_FALLBACK "SDL_VIDEO_EGL_ALLOW_GETDISPLAY_FALLBACK"
```

</div>

## Remarks

The variable can be set to one of the following values:

- "0": Do not fall back to eglGetDisplay.
- "1": Fall back to eglGetDisplay if eglGetPlatformDisplay fails.
  (default)

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
