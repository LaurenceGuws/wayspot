# CategoryMutex

SDL offers several thread synchronization primitives. This document
can't cover the complicated topic of thread safety, but reading up on
what each of these primitives are, why they are useful, and how to
correctly use them is vital to writing correct and safe multithreaded
programs.

- Mutexes: [SDL_CreateMutex](SDL_CreateMutex.html)()
- Read/Write locks: [SDL_CreateRWLock](SDL_CreateRWLock.html)()
- Semaphores: [SDL_CreateSemaphore](SDL_CreateSemaphore.html)()
- Condition variables: [SDL_CreateCondition](SDL_CreateCondition.html)()

SDL also offers a datatype, [SDL_InitState](SDL_InitState.html), which
can be used to make sure only one thread initializes/deinitializes some
resource that several threads might try to use for the first time
simultaneously.

## Functions

- [SDL_BroadcastCondition](SDL_BroadcastCondition.html)
- [SDL_CreateCondition](SDL_CreateCondition.html)
- [SDL_CreateMutex](SDL_CreateMutex.html)
- [SDL_CreateRWLock](SDL_CreateRWLock.html)
- [SDL_CreateSemaphore](SDL_CreateSemaphore.html)
- [SDL_DestroyCondition](SDL_DestroyCondition.html)
- [SDL_DestroyMutex](SDL_DestroyMutex.html)
- [SDL_DestroyRWLock](SDL_DestroyRWLock.html)
- [SDL_DestroySemaphore](SDL_DestroySemaphore.html)
- [SDL_GetSemaphoreValue](SDL_GetSemaphoreValue.html)
- [SDL_LockMutex](SDL_LockMutex.html)
- [SDL_LockRWLockForReading](SDL_LockRWLockForReading.html)
- [SDL_LockRWLockForWriting](SDL_LockRWLockForWriting.html)
- [SDL_SetInitialized](SDL_SetInitialized.html)
- [SDL_ShouldInit](SDL_ShouldInit.html)
- [SDL_ShouldQuit](SDL_ShouldQuit.html)
- [SDL_SignalCondition](SDL_SignalCondition.html)
- [SDL_SignalSemaphore](SDL_SignalSemaphore.html)
- [SDL_TryLockMutex](SDL_TryLockMutex.html)
- [SDL_TryLockRWLockForReading](SDL_TryLockRWLockForReading.html)
- [SDL_TryLockRWLockForWriting](SDL_TryLockRWLockForWriting.html)
- [SDL_TryWaitSemaphore](SDL_TryWaitSemaphore.html)
- [SDL_UnlockMutex](SDL_UnlockMutex.html)
- [SDL_UnlockRWLock](SDL_UnlockRWLock.html)
- [SDL_WaitCondition](SDL_WaitCondition.html)
- [SDL_WaitConditionTimeout](SDL_WaitConditionTimeout.html)
- [SDL_WaitSemaphore](SDL_WaitSemaphore.html)
- [SDL_WaitSemaphoreTimeout](SDL_WaitSemaphoreTimeout.html)

## Datatypes

- [SDL_Condition](SDL_Condition.html)
- [SDL_Mutex](SDL_Mutex.html)
- [SDL_RWLock](SDL_RWLock.html)
- [SDL_Semaphore](SDL_Semaphore.html)

## Structs

- [SDL_InitState](SDL_InitState.html)

## Enums

- [SDL_InitStatus](SDL_InitStatus.html)

## Macros

- [SDL_ACQUIRE](SDL_ACQUIRE.html)
- [SDL_ACQUIRE_SHARED](SDL_ACQUIRE_SHARED.html)
- [SDL_ACQUIRED_AFTER](SDL_ACQUIRED_AFTER.html)
- [SDL_ACQUIRED_BEFORE](SDL_ACQUIRED_BEFORE.html)
- [SDL_ASSERT_CAPABILITY](SDL_ASSERT_CAPABILITY.html)
- [SDL_ASSERT_SHARED_CAPABILITY](SDL_ASSERT_SHARED_CAPABILITY.html)
- [SDL_CAPABILITY](SDL_CAPABILITY.html)
- [SDL_EXCLUDES](SDL_EXCLUDES.html)
- [SDL_GUARDED_BY](SDL_GUARDED_BY.html)
- [SDL_NO_THREAD_SAFETY_ANALYSIS](SDL_NO_THREAD_SAFETY_ANALYSIS.html)
- [SDL_PT_GUARDED_BY](SDL_PT_GUARDED_BY.html)
- [SDL_RELEASE](SDL_RELEASE.html)
- [SDL_RELEASE_GENERIC](SDL_RELEASE_GENERIC.html)
- [SDL_RELEASE_SHARED](SDL_RELEASE_SHARED.html)
- [SDL_REQUIRES](SDL_REQUIRES.html)
- [SDL_REQUIRES_SHARED](SDL_REQUIRES_SHARED.html)
- [SDL_RETURN_CAPABILITY](SDL_RETURN_CAPABILITY.html)
- [SDL_SCOPED_CAPABILITY](SDL_SCOPED_CAPABILITY.html)
- [SDL_THREAD_ANNOTATION_ATTRIBUTE\_\_](SDL_THREAD_ANNOTATION_ATTRIBUTE__.html)
- [SDL_TRY_ACQUIRE](SDL_TRY_ACQUIRE.html)
- [SDL_TRY_ACQUIRE_SHARED](SDL_TRY_ACQUIRE_SHARED.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
