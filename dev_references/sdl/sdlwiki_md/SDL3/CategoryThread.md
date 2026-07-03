# CategoryThread

SDL offers cross-platform thread management functions. These are mostly
concerned with starting threads, setting their priority, and dealing
with their termination.

In addition, there is support for Thread Local Storage (data that is
unique to each thread, but accessed from a single key).

On platforms without thread support (such as Emscripten when built
without pthreads), these functions still exist, but things like
[SDL_CreateThread](SDL_CreateThread.html)() will report failure without
doing anything.

If you're going to work with threads, you almost certainly need to have
a good understanding of thread safety measures: locking and
synchronization mechanisms are handled by the functions in
[SDL_mutex](SDL_mutex.html).h.

You can read about the SDL_mutex.h pieces on the wiki in
[CategoryMutex](CategoryMutex.html).

## Functions

- [SDL_CleanupTLS](SDL_CleanupTLS.html)
- [SDL_CreateThread](SDL_CreateThread.html)
- [SDL_CreateThreadWithProperties](SDL_CreateThreadWithProperties.html)
- [SDL_DetachThread](SDL_DetachThread.html)
- [SDL_GetCurrentThreadID](SDL_GetCurrentThreadID.html)
- [SDL_GetThreadID](SDL_GetThreadID.html)
- [SDL_GetThreadName](SDL_GetThreadName.html)
- [SDL_GetThreadState](SDL_GetThreadState.html)
- [SDL_GetTLS](SDL_GetTLS.html)
- [SDL_SetCurrentThreadPriority](SDL_SetCurrentThreadPriority.html)
- [SDL_SetTLS](SDL_SetTLS.html)
- [SDL_WaitThread](SDL_WaitThread.html)

## Datatypes

- [SDL_Thread](SDL_Thread.html)
- [SDL_ThreadFunction](SDL_ThreadFunction.html)
- [SDL_ThreadID](SDL_ThreadID.html)
- [SDL_TLSDestructorCallback](SDL_TLSDestructorCallback.html)
- [SDL_TLSID](SDL_TLSID.html)

## Structs

- (none.)

## Enums

- [SDL_ThreadPriority](SDL_ThreadPriority.html)
- [SDL_ThreadState](SDL_ThreadState.html)

## Macros

- (none.)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
