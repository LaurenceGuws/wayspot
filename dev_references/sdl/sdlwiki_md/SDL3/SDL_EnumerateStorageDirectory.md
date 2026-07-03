# SDL_EnumerateStorageDirectory

Enumerate a directory in a storage container through a callback
function.

## Header File

Defined in
[\<SDL3/SDL_storage.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_storage.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_EnumerateStorageDirectory(SDL_Storage *storage, const char *path, SDL_EnumerateDirectoryCallback callback, void *userdata);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Storage](SDL_Storage.html) \* | **storage** | a storage container. |
| const char \* | **path** | the path of the directory to enumerate, or NULL for the root. |
| [SDL_EnumerateDirectoryCallback](SDL_EnumerateDirectoryCallback.html) | **callback** | a function that is called for each entry in the directory. |
| void \* | **userdata** | a pointer that is passed to `callback`. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function provides every directory entry through an app-provided
callback, called once for each directory entry, until all results have
been provided or the callback returns either
[SDL_ENUM_SUCCESS](SDL_ENUM_SUCCESS.html) or
[SDL_ENUM_FAILURE](SDL_ENUM_FAILURE.html).

This will return false if there was a system problem in general, or if a
callback returns [SDL_ENUM_FAILURE](SDL_ENUM_FAILURE.html). A successful
return means a callback returned
[SDL_ENUM_SUCCESS](SDL_ENUM_SUCCESS.html) to halt enumeration, or all
directory entries were enumerated.

If `path` is NULL, this is treated as a request to enumerate the root of
the storage container's tree. An empty string also works for this.

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
// Example program
// Use SDL3 to enumerate all directories in title storage

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>


SDL_EnumerationResult
my_enumerate_dir_callback(void *userdata, const char* dirname, const char* fname)
{
    SDL_Log("dirname: %s | fname: %s", dirname, fname);
    return SDL_ENUM_CONTINUE;
}

int
main(int argc, char** argv)
{
    SDL_Storage *storage = SDL_OpenTitleStorage("", 0);
    if(storage == NULL) {
        SDL_Log("Unable to open storage %s", SDL_GetError());
    }

    if(!SDL_EnumerateStorageDirectory(storage, NULL, my_enumerate_dir_callback, NULL)) {
        SDL_Log("There was a system problem or the callback indicated failure.");
    } else {
        SDL_Log("All directories enumerated or the callback halted enumeration.");
    }

    return 0;
}
```

</div>

## See Also

- [SDL_StorageReady](SDL_StorageReady.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryStorage](CategoryStorage.html)
