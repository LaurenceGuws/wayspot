# SDL_GetAndroidCachePath

Get the path used for caching data for this Android application.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetAndroidCachePath(void);
```

</div>

## Return Value

(const char \*) Returns the path used for caches for this application on
success or NULL on failure; call [SDL_GetError](SDL_GetError.html)() for
more information.

## Remarks

This path is unique to your application, but is public and can be
written to by other applications.

Your cache path is typically: `/data/data/your.app.package/cache/`.

This is a C wrapper over `android.content.Context.getCacheDir()`:

<https://developer.android.com/reference/android/content/Context#getCacheDir()>

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetAndroidInternalStoragePath](SDL_GetAndroidInternalStoragePath.html)
- [SDL_GetAndroidExternalStoragePath](SDL_GetAndroidExternalStoragePath.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySystem](CategorySystem.html)
