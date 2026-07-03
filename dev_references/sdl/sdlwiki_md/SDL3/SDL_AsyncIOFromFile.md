# SDL_AsyncIOFromFile

Use this function to create a new [SDL_AsyncIO](SDL_AsyncIO.html) object
for reading from and/or writing to a named file.

## Header File

Defined in
[\<SDL3/SDL_asyncio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_asyncio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_AsyncIO * SDL_AsyncIOFromFile(const char *file, const char *mode);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **file** | a UTF-8 string representing the filename to open. |
| const char \* | **mode** | an ASCII string representing the mode to be used for opening the file. |

## Return Value

([SDL_AsyncIO](SDL_AsyncIO.html) \*) Returns a pointer to the
[SDL_AsyncIO](SDL_AsyncIO.html) structure that is created or NULL on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The `mode` string understands the following values:

- "r": Open a file for reading only. It must exist.
- "w": Open a file for writing only. It will create missing files or
  truncate existing ones.
- "r+": Open a file for update both reading and writing. The file must
  exist.
- "w+": Create an empty file for both reading and writing. If a file
  with the same name already exists its content is erased and the file
  is treated as a new empty file.

There is no "b" mode, as there is only "binary" style I/O, and no "a"
mode for appending, since you specify the position when starting a task.

This function supports Unicode filenames, but they must be encoded in
UTF-8 format, regardless of the underlying operating system.

This call is *not* asynchronous; it will open the file before returning,
under the assumption that doing so is generally a fast operation. Future
reads and writes to the opened file will be async, however.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CloseAsyncIO](SDL_CloseAsyncIO.html)
- [SDL_ReadAsyncIO](SDL_ReadAsyncIO.html)
- [SDL_WriteAsyncIO](SDL_WriteAsyncIO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAsyncIO](CategoryAsyncIO.html)
