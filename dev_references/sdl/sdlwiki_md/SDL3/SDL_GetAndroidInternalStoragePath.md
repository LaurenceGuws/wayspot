# SDL_GetAndroidInternalStoragePath

Get the path used for internal storage for this Android application.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetAndroidInternalStoragePath(void);
```

</div>

## Return Value

(const char \*) Returns the path used for internal storage or NULL on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This path is unique to your application and cannot be written to by
other applications.

Your internal storage path is typically:
`/data/data/your.app.package/files`.

This is a C wrapper over `android.content.Context.getFilesDir()`:

<https://developer.android.com/reference/android/content/Context#getFilesDir()>

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetAndroidExternalStoragePath](SDL_GetAndroidExternalStoragePath.html)
- [SDL_GetAndroidCachePath](SDL_GetAndroidCachePath.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySystem](CategorySystem.html)
