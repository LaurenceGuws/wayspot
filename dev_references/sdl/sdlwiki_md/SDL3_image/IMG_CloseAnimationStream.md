###### (This function is part of SDL_image, a separate library from SDL.)

# IMG_CloseAnimationStream

Close an animation stream, finishing any encoding.

## Header File

Defined in
[\<SDL3_image/SDL_image.h\>](https://github.com/libsdl-org/SDL_image/blob/main/include/SDL3_image/SDL_image.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool IMG_CloseAnimationStream(IMG_AnimationStream *stream);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [IMG_AnimationStream](IMG_AnimationStream.html) \* | **stream** | the stream to close. |

## Return Value

(bool) Returns true on success or false on failure; call SDL_GetError()
for more information.

## Remarks

Calling this function frees the animation stream, and returns the final
status of the encoding process.

## Version

This function is available since SDL_image 3.4.0.

## See Also

- [IMG_CreateAnimationStream](IMG_CreateAnimationStream.html)
- [IMG_CreateAnimationStream_IO](IMG_CreateAnimationStream_IO.html)
- [IMG_CreateAnimationStreamWithProperties](IMG_CreateAnimationStreamWithProperties.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLImage](CategorySDLImage.html)
