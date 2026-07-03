###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_OpenFontWithProperties

Create a font with the specified properties.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
TTF_Font * TTF_OpenFontWithProperties(SDL_PropertiesID props);


#define TTF_PROP_FONT_CREATE_FILENAME_STRING            "SDL_ttf.font.create.filename"
#define TTF_PROP_FONT_CREATE_IOSTREAM_POINTER           "SDL_ttf.font.create.iostream"
#define TTF_PROP_FONT_CREATE_IOSTREAM_OFFSET_NUMBER     "SDL_ttf.font.create.iostream.offset"
#define TTF_PROP_FONT_CREATE_IOSTREAM_AUTOCLOSE_BOOLEAN "SDL_ttf.font.create.iostream.autoclose"
#define TTF_PROP_FONT_CREATE_SIZE_FLOAT                 "SDL_ttf.font.create.size"
#define TTF_PROP_FONT_CREATE_FACE_NUMBER                "SDL_ttf.font.create.face"
#define TTF_PROP_FONT_CREATE_HORIZONTAL_DPI_NUMBER      "SDL_ttf.font.create.hdpi"
#define TTF_PROP_FONT_CREATE_VERTICAL_DPI_NUMBER        "SDL_ttf.font.create.vdpi"
#define TTF_PROP_FONT_CREATE_EXISTING_FONT_POINTER      "SDL_ttf.font.create.existing_font"
```

</div>

## Function Parameters

|                  |           |                        |
|------------------|-----------|------------------------|
| SDL_PropertiesID | **props** | the properties to use. |

## Return Value

([TTF_Font](TTF_Font.html) \*) Returns a valid
[TTF_Font](TTF_Font.html), or NULL on failure; call SDL_GetError() for
more information.

## Remarks

These are the supported properties:

- [`TTF_PROP_FONT_CREATE_FILENAME_STRING`](TTF_PROP_FONT_CREATE_FILENAME_STRING.html):
  the font file to open, if an SDL_IOStream isn't being used. This is
  required if
  [`TTF_PROP_FONT_CREATE_IOSTREAM_POINTER`](TTF_PROP_FONT_CREATE_IOSTREAM_POINTER.html)
  and
  [`TTF_PROP_FONT_CREATE_EXISTING_FONT_POINTER`](TTF_PROP_FONT_CREATE_EXISTING_FONT_POINTER.html)
  aren't set.
- [`TTF_PROP_FONT_CREATE_IOSTREAM_POINTER`](TTF_PROP_FONT_CREATE_IOSTREAM_POINTER.html):
  an SDL_IOStream containing the font to be opened. This should not be
  closed until the font is closed. This is required if
  [`TTF_PROP_FONT_CREATE_FILENAME_STRING`](TTF_PROP_FONT_CREATE_FILENAME_STRING.html)
  and
  [`TTF_PROP_FONT_CREATE_EXISTING_FONT_POINTER`](TTF_PROP_FONT_CREATE_EXISTING_FONT_POINTER.html)
  aren't set.
- [`TTF_PROP_FONT_CREATE_IOSTREAM_OFFSET_NUMBER`](TTF_PROP_FONT_CREATE_IOSTREAM_OFFSET_NUMBER.html):
  the offset in the iostream for the beginning of the font, defaults to
  0.
- [`TTF_PROP_FONT_CREATE_IOSTREAM_AUTOCLOSE_BOOLEAN`](TTF_PROP_FONT_CREATE_IOSTREAM_AUTOCLOSE_BOOLEAN.html):
  true if closing the font should also close the associated
  SDL_IOStream.
- [`TTF_PROP_FONT_CREATE_SIZE_FLOAT`](TTF_PROP_FONT_CREATE_SIZE_FLOAT.html):
  the point size of the font. Some .fon fonts will have several sizes
  embedded in the file, so the point size becomes the index of choosing
  which size. If the value is too high, the last indexed size will be
  the default.
- [`TTF_PROP_FONT_CREATE_FACE_NUMBER`](TTF_PROP_FONT_CREATE_FACE_NUMBER.html):
  the face index of the font, if the font contains multiple font faces.
- [`TTF_PROP_FONT_CREATE_HORIZONTAL_DPI_NUMBER`](TTF_PROP_FONT_CREATE_HORIZONTAL_DPI_NUMBER.html):
  the horizontal DPI to use for font rendering, defaults to
  [`TTF_PROP_FONT_CREATE_VERTICAL_DPI_NUMBER`](TTF_PROP_FONT_CREATE_VERTICAL_DPI_NUMBER.html)
  if set, or 72 otherwise.
- [`TTF_PROP_FONT_CREATE_VERTICAL_DPI_NUMBER`](TTF_PROP_FONT_CREATE_VERTICAL_DPI_NUMBER.html):
  the vertical DPI to use for font rendering, defaults to
  [`TTF_PROP_FONT_CREATE_HORIZONTAL_DPI_NUMBER`](TTF_PROP_FONT_CREATE_HORIZONTAL_DPI_NUMBER.html)
  if set, or 72 otherwise.
- [`TTF_PROP_FONT_CREATE_EXISTING_FONT_POINTER`](TTF_PROP_FONT_CREATE_EXISTING_FONT_POINTER.html):
  an optional [TTF_Font](TTF_Font.html) that, if set, will be used as
  the font data source and the initial size and style of the new font.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_CloseFont](TTF_CloseFont.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
