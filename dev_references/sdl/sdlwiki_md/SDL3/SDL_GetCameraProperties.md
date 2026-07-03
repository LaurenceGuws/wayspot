# SDL_GetCameraProperties

Get the properties associated with an opened camera.

## Header File

Defined in
[\<SDL3/SDL_camera.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_camera.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_PropertiesID SDL_GetCameraProperties(SDL_Camera *camera);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Camera](SDL_Camera.html) \* | **camera** | the [SDL_Camera](SDL_Camera.html) obtained from [SDL_OpenCamera](SDL_OpenCamera.html)(). |

## Return Value

([SDL_PropertiesID](SDL_PropertiesID.html)) Returns a valid property ID
on success or 0 on failure; call [SDL_GetError](SDL_GetError.html)() for
more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryCamera](CategoryCamera.html)
