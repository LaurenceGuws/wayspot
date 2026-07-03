# SDL_RenderDebugText

Draw debug text to an [SDL_Renderer](SDL_Renderer.html).

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RenderDebugText(SDL_Renderer *renderer, float x, float y, const char *str);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the renderer which should draw a line of text. |
| float | **x** | the x coordinate where the top-left corner of the text will draw. |
| float | **y** | the y coordinate where the top-left corner of the text will draw. |
| const char \* | **str** | the string to render. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function will render a string of text to an
[SDL_Renderer](SDL_Renderer.html). Note that this is a convenience
function for debugging, with severe limitations, and not intended to be
used for production apps and games.

Among these limitations:

- It accepts UTF-8 strings, but will only renders ASCII characters.
- It has a single, tiny size (8x8 pixels). You can use logical
  presentation or [SDL_SetRenderScale](SDL_SetRenderScale.html)() to
  adjust it.
- It uses a simple, hardcoded bitmap font. It does not allow different
  font selections and it does not support truetype, for proper scaling.
- It does no word-wrapping and does not treat newline characters as a
  line break. If the text goes out of the window, it's gone.

For serious text rendering, there are several good options, such as
[SDL_ttf](SDL_ttf.html), stb_truetype, or other external libraries.

On first use, this will create an internal texture for rendering glyphs.
This texture will live until the renderer is destroyed.

The text is drawn in the color specified by
[SDL_SetRenderDrawColor](SDL_SetRenderDrawColor.html)().

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_RenderDebugTextFormat](SDL_RenderDebugTextFormat.html)
- [SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE](SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
