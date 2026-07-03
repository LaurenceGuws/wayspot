###### (This function is part of SDL_image, a separate library from SDL.)

# IMG_CloseAnimationEncoder

Close an animation encoder, finishing any encoding.

## Header File

Defined in
[\<SDL3_image/SDL_image.h\>](https://github.com/libsdl-org/SDL_image/blob/main/include/SDL3_image/SDL_image.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool IMG_CloseAnimationEncoder(IMG_AnimationEncoder *encoder);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [IMG_AnimationEncoder](IMG_AnimationEncoder.html) \* | **encoder** | the encoder to close. |

## Return Value

(bool) Returns true on success or false on failure; call SDL_GetError()
for more information.

## Remarks

Calling this function frees the animation encoder, and returns the final
status of the encoding process.

## Version

This function is available since SDL_image 3.4.0.

## See Also

- [IMG_CreateAnimationEncoder](IMG_CreateAnimationEncoder.html)
- [IMG_CreateAnimationEncoder_IO](IMG_CreateAnimationEncoder_IO.html)
- [IMG_CreateAnimationEncoderWithProperties](IMG_CreateAnimationEncoderWithProperties.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLImage](CategorySDLImage.html)
