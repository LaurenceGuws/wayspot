###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_TextEngine

A text engine used to create text objects.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct TTF_TextEngine TTF_TextEngine;
```

</div>

## Remarks

This is a public interface that can be used by applications and
libraries to perform customize rendering with text objects. See
\<SDL3_ttf/SDL_textengine.h\> for details.

There are three text engines provided with the library:

- Drawing to an SDL_Surface, created with
  [TTF_CreateSurfaceTextEngine](TTF_CreateSurfaceTextEngine.html)()
- Drawing with an SDL 2D renderer, created with
  [TTF_CreateRendererTextEngine](TTF_CreateRendererTextEngine.html)()
- Drawing with the SDL GPU API, created with
  [TTF_CreateGPUTextEngine](TTF_CreateGPUTextEngine.html)()

## Version

This struct is available since SDL_ttf 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategorySDLTTF](CategorySDLTTF.html)
