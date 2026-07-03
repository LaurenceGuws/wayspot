# SDL_OpenTitleStorage

Opens up a read-only container for the application's filesystem.

## Header File

Defined in
[\<SDL3/SDL_storage.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_storage.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Storage * SDL_OpenTitleStorage(const char *override, SDL_PropertiesID props);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **override** | a path to override the backend's default title root. |
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | a property list that may contain backend-specific information. |

## Return Value

([SDL_Storage](SDL_Storage.html) \*) Returns a title storage container
on success or NULL on failure; call [SDL_GetError](SDL_GetError.html)()
for more information.

## Remarks

By default, [SDL_OpenTitleStorage](SDL_OpenTitleStorage.html) uses the
generic storage implementation. When the path override is not provided,
the generic implementation will use the output of
[SDL_GetBasePath](SDL_GetBasePath.html) as the base path.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CloseStorage](SDL_CloseStorage.html)
- [SDL_GetStorageFileSize](SDL_GetStorageFileSize.html)
- [SDL_OpenUserStorage](SDL_OpenUserStorage.html)
- [SDL_ReadStorageFile](SDL_ReadStorageFile.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStorage](CategoryStorage.html)
