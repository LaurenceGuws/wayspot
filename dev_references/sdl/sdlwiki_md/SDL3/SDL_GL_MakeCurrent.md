# SDL_GL_MakeCurrent

Set up an OpenGL context for rendering into an OpenGL window.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GL_MakeCurrent(SDL_Window *window, SDL_GLContext context);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to associate with the context. |
| [SDL_GLContext](SDL_GLContext.html) | **context** | the OpenGL context to associate with the window. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The context must have been created with a compatible window.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GL_CreateContext](SDL_GL_CreateContext.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
