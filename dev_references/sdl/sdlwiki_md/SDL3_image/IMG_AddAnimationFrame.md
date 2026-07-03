###### (This function is part of SDL_image, a separate library from SDL.)

# IMG_AddAnimationFrame

Add a frame to a stream of images being saved.

## Header File

Defined in
[\<SDL3_image/SDL_image.h\>](https://github.com/libsdl-org/SDL_image/blob/main/include/SDL3_image/SDL_image.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool IMG_AddAnimationFrame(IMG_AnimationStream *stream, SDL_Surface *surface, Uint64 pts);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [IMG_AnimationStream](IMG_AnimationStream.html) \* | **stream** | the stream receiving images. |
| SDL_Surface \* | **surface** | the surface to add as the next frame in the animation. |
| Uint64 | **pts** | the presentation timestamp of the frame, usually in milliseconds but can be other units if the [`IMG_PROP_ANIMATION_STREAM_CREATE_TIMEBASE_DENOMINATOR_NUMBER`](IMG_PROP_ANIMATION_STREAM_CREATE_TIMEBASE_DENOMINATOR_NUMBER.html) property is set when creating the stream. |

## Return Value

(bool) Returns true on success or false on failure; call SDL_GetError()
for more information.

## Version

This function is available since SDL_image 3.4.0.

## See Also

- [IMG_CreateAnimationStream](IMG_CreateAnimationStream.html)
- [IMG_CreateAnimationStream_IO](IMG_CreateAnimationStream_IO.html)
- [IMG_CreateAnimationStreamWithProperties](IMG_CreateAnimationStreamWithProperties.html)
- [IMG_CloseAnimationStream](IMG_CloseAnimationStream.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLImage](CategorySDLImage.html)
