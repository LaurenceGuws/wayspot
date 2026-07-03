# CategoryFilesystem

SDL offers an API for examining and manipulating the system's
filesystem. This covers most things one would need to do with
directories, except for actual file I/O (which is covered by
[CategoryIOStream](CategoryIOStream.html) and
[CategoryAsyncIO](CategoryAsyncIO.html) instead).

There are functions to answer necessary path questions:

- Where is my app's data? [SDL_GetBasePath](SDL_GetBasePath.html)().
- Where can I safely write files?
  [SDL_GetPrefPath](SDL_GetPrefPath.html)().
- Where are paths like Downloads, Desktop, Music?
  [SDL_GetUserFolder](SDL_GetUserFolder.html)().
- What is this thing at this location?
  [SDL_GetPathInfo](SDL_GetPathInfo.html)().
- What items live in this folder?
  [SDL_EnumerateDirectory](SDL_EnumerateDirectory.html)().
- What items live in this folder by wildcard?
  [SDL_GlobDirectory](SDL_GlobDirectory.html)().
- What is my current working directory?
  [SDL_GetCurrentDirectory](SDL_GetCurrentDirectory.html)().

SDL also offers functions to manipulate the directory tree: renaming,
removing, copying files.

## Functions

- [SDL_CopyFile](SDL_CopyFile.html)
- [SDL_CreateDirectory](SDL_CreateDirectory.html)
- [SDL_EnumerateDirectory](SDL_EnumerateDirectory.html)
- [SDL_GetBasePath](SDL_GetBasePath.html)
- [SDL_GetCurrentDirectory](SDL_GetCurrentDirectory.html)
- [SDL_GetPathInfo](SDL_GetPathInfo.html)
- [SDL_GetPrefPath](SDL_GetPrefPath.html)
- [SDL_GetUserFolder](SDL_GetUserFolder.html)
- [SDL_GlobDirectory](SDL_GlobDirectory.html)
- [SDL_RemovePath](SDL_RemovePath.html)
- [SDL_RenamePath](SDL_RenamePath.html)

## Datatypes

- [SDL_EnumerateDirectoryCallback](SDL_EnumerateDirectoryCallback.html)
- [SDL_GlobFlags](SDL_GlobFlags.html)

## Structs

- [SDL_PathInfo](SDL_PathInfo.html)

## Enums

- [SDL_EnumerationResult](SDL_EnumerationResult.html)
- [SDL_Folder](SDL_Folder.html)
- [SDL_PathType](SDL_PathType.html)

## Macros

- (none.)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
