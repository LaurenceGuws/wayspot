# SDL_GL_GetCurrentContext

Get the currently active OpenGL context.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GLContext SDL_GL_GetCurrentContext(void);
```

</div>

## Return Value

([SDL_GLContext](SDL_GLContext.html)) Returns the currently active
OpenGL context or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GL_MakeCurrent](SDL_GL_MakeCurrent.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
