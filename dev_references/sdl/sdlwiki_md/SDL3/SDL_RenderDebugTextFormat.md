# SDL_RenderDebugTextFormat

Draw debug text to an [SDL_Renderer](SDL_Renderer.html).

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RenderDebugTextFormat(SDL_Renderer *renderer, float x, float y, const char *fmt, ...);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the renderer which should draw the text. |
| float | **x** | the x coordinate where the top-left corner of the text will draw. |
| float | **y** | the y coordinate where the top-left corner of the text will draw. |
| const char \* | **fmt** | the format string to draw. |
| ... | **...** | additional parameters matching % tokens in the `fmt` string, if any. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function will render a printf()-style format string to a renderer.
Note that this is a convenience function for debugging, with severe
limitations, and is not intended to be used for production apps and
games.

For the full list of limitations and other useful information, see
[SDL_RenderDebugText](SDL_RenderDebugText.html).

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_RenderDebugText](SDL_RenderDebugText.html)
- [SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE](SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
