###### (This function is part of SDL_image, a separate library from SDL.)

# IMG_CreateAnimatedCursor

Create an animated cursor from an animation.

## Header File

Defined in
[\<SDL3_image/SDL_image.h\>](https://github.com/libsdl-org/SDL_image/blob/main/include/SDL3_image/SDL_image.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Cursor * IMG_CreateAnimatedCursor(IMG_Animation *anim, int hot_x, int hot_y);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [IMG_Animation](IMG_Animation.html) \* | **anim** | an animation to use to create an animated cursor. |
| int | **hot_x** | the x position of the cursor hot spot. |
| int | **hot_y** | the y position of the cursor hot spot. |

## Return Value

(SDL_Cursor \*) Returns the new cursor on success or NULL on failure;
call SDL_GetError() for more information.

## Version

This function is available since SDL_image 3.4.0.

## See Also

- [IMG_LoadAnimation](IMG_LoadAnimation.html)
- [IMG_LoadAnimation_IO](IMG_LoadAnimation_IO.html)
- [IMG_LoadAnimationTyped_IO](IMG_LoadAnimationTyped_IO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLImage](CategorySDLImage.html)
