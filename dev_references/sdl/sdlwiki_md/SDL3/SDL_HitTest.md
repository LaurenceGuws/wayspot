# SDL_HitTest

Callback used for hit-testing.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef SDL_HitTestResult (SDLCALL *SDL_HitTest)(SDL_Window *win, const SDL_Point *area, void *data);
```

</div>

## Function Parameters

|  |  |
|----|----|
| **win** | the [SDL_Window](SDL_Window.html) where hit-testing was set on. |
| **area** | an [SDL_Point](SDL_Point.html) which should be hit-tested. |
| **data** | what was passed as `callback_data` to [SDL_SetWindowHitTest](SDL_SetWindowHitTest.html)(). |

## Return Value

Returns an [SDL_HitTestResult](SDL_HitTestResult.html) value.

## See Also

- [SDL_SetWindowHitTest](SDL_SetWindowHitTest.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryVideo](CategoryVideo.html)
