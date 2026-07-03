# SDL_RemovePath

Remove a file or an empty directory.

## Header File

Defined in
[\<SDL3/SDL_filesystem.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_filesystem.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RemovePath(const char *path);
```

</div>

## Function Parameters

|               |          |                                         |
|---------------|----------|-----------------------------------------|
| const char \* | **path** | the path to remove from the filesystem. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Directories that are not empty will fail; this function will not
recursely delete directory trees.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryFilesystem](CategoryFilesystem.html)
