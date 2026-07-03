###### (This function is part of SDL_image, a separate library from SDL.)

# IMG_CreateAnimationStreamWithProperties

Create an animation stream with the specified properties.

## Header File

Defined in
[\<SDL3_image/SDL_image.h\>](https://github.com/libsdl-org/SDL_image/blob/main/include/SDL3_image/SDL_image.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
IMG_AnimationStream * IMG_CreateAnimationStreamWithProperties(SDL_PropertiesID props);


#define IMG_PROP_ANIMATION_STREAM_CREATE_FILENAME_STRING                "SDL_image.animation_stream.create.filename"
#define IMG_PROP_ANIMATION_STREAM_CREATE_IOSTREAM_POINTER               "SDL_image.animation_stream.create.iostream"
#define IMG_PROP_ANIMATION_STREAM_CREATE_IOSTREAM_AUTOCLOSE_BOOLEAN     "SDL_image.animation_stream.create.iostream.autoclose"
#define IMG_PROP_ANIMATION_STREAM_CREATE_TYPE_STRING                    "SDL_image.animation_stream.create.type"
#define IMG_PROP_ANIMATION_STREAM_CREATE_QUALITY_NUMBER                 "SDL_image.animation_stream.create.quality"
#define IMG_PROP_ANIMATION_STREAM_CREATE_TIMEBASE_NUMERATOR_NUMBER      "SDL_image.animation_stream.create.timebase.numerator"
#define IMG_PROP_ANIMATION_STREAM_CREATE_TIMEBASE_DENOMINATOR_NUMBER    "SDL_image.animation_stream.create.timebase.denominator"
```

</div>

## Function Parameters

|                  |           |                                         |
|------------------|-----------|-----------------------------------------|
| SDL_PropertiesID | **props** | the properties of the animation stream. |

## Return Value

([IMG_AnimationStream](IMG_AnimationStream.html) \*) Returns a new
[IMG_AnimationStream](IMG_AnimationStream.html), or NULL on failure;
call SDL_GetError() for more information.

## Remarks

These are the supported properties:

- [`IMG_PROP_ANIMATION_STREAM_CREATE_FILENAME_STRING`](IMG_PROP_ANIMATION_STREAM_CREATE_FILENAME_STRING.html):
  the file to save, if an SDL_IOStream isn't being used. This is
  required if
  [`IMG_PROP_ANIMATION_STREAM_CREATE_IOSTREAM_POINTER`](IMG_PROP_ANIMATION_STREAM_CREATE_IOSTREAM_POINTER.html)
  isn't set.
- [`IMG_PROP_ANIMATION_STREAM_CREATE_IOSTREAM_POINTER`](IMG_PROP_ANIMATION_STREAM_CREATE_IOSTREAM_POINTER.html):
  an SDL_IOStream that will be used to save the stream. This should not
  be closed until the animation stream is closed. This is required if
  [`IMG_PROP_ANIMATION_STREAM_CREATE_FILENAME_STRING`](IMG_PROP_ANIMATION_STREAM_CREATE_FILENAME_STRING.html)
  isn't set.
- [`IMG_PROP_ANIMATION_STREAM_CREATE_IOSTREAM_AUTOCLOSE_BOOLEAN`](IMG_PROP_ANIMATION_STREAM_CREATE_IOSTREAM_AUTOCLOSE_BOOLEAN.html):
  true if closing the animation stream should also close the associated
  SDL_IOStream.
- [`IMG_PROP_ANIMATION_STREAM_CREATE_TYPE_STRING`](IMG_PROP_ANIMATION_STREAM_CREATE_TYPE_STRING.html):
  the output file type, e.g. "webp", defaults to the file extension if
  [`IMG_PROP_ANIMATION_STREAM_CREATE_FILENAME_STRING`](IMG_PROP_ANIMATION_STREAM_CREATE_FILENAME_STRING.html)
  is set.
- [`IMG_PROP_ANIMATION_STREAM_CREATE_QUALITY_NUMBER`](IMG_PROP_ANIMATION_STREAM_CREATE_QUALITY_NUMBER.html):
  the compression quality, in the range of 0 to 100. The higher the
  number, the higher the quality and file size. This defaults to a
  balanced value for compression and quality.
- [`IMG_PROP_ANIMATION_STREAM_CREATE_TIMEBASE_NUMERATOR_NUMBER`](IMG_PROP_ANIMATION_STREAM_CREATE_TIMEBASE_NUMERATOR_NUMBER.html):
  the numerator of the fraction used to multiply the pts to convert it
  to seconds. This defaults to 1.
- [`IMG_PROP_ANIMATION_STREAM_CREATE_TIMEBASE_DENOMINATOR_NUMBER`](IMG_PROP_ANIMATION_STREAM_CREATE_TIMEBASE_DENOMINATOR_NUMBER.html):
  the denominator of the fraction used to multiply the pts to convert it
  to seconds. This defaults to 1000.

## Version

This function is available since SDL_image 3.4.0.

## See Also

- [IMG_CreateAnimationStream](IMG_CreateAnimationStream.html)
- [IMG_CreateAnimationStream_IO](IMG_CreateAnimationStream_IO.html)
- [IMG_AddAnimationFrame](IMG_AddAnimationFrame.html)
- [IMG_CloseAnimationStream](IMG_CloseAnimationStream.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLImage](CategorySDLImage.html)
