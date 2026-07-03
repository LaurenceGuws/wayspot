# CategoryAtomic

Atomic operations.

IMPORTANT: If you are not an expert in concurrent lockless programming,
you should not be using any functions in this file. You should be
protecting your data structures with full mutexes instead.

***Seriously, here be dragons!***

You can find out a little more about lockless programming and the subtle
issues that can arise here:
<https://learn.microsoft.com/en-us/windows/win32/dxtecharts/lockless-programming>

There's also lots of good information here:

- <https://www.1024cores.net/home/lock-free-algorithms>
- <https://preshing.com/>

These operations may or may not actually be implemented using processor
specific atomic operations. When possible they are implemented as true
processor specific atomic operations. When that is not possible the are
implemented using locks that *do* use the available atomic operations.

All of the atomic operations that modify memory are full memory
barriers.

## Functions

- [SDL_AddAtomicInt](SDL_AddAtomicInt.html)
- [SDL_AddAtomicU32](SDL_AddAtomicU32.html)
- [SDL_CompareAndSwapAtomicInt](SDL_CompareAndSwapAtomicInt.html)
- [SDL_CompareAndSwapAtomicPointer](SDL_CompareAndSwapAtomicPointer.html)
- [SDL_CompareAndSwapAtomicU32](SDL_CompareAndSwapAtomicU32.html)
- [SDL_GetAtomicInt](SDL_GetAtomicInt.html)
- [SDL_GetAtomicPointer](SDL_GetAtomicPointer.html)
- [SDL_GetAtomicU32](SDL_GetAtomicU32.html)
- [SDL_LockSpinlock](SDL_LockSpinlock.html)
- [SDL_MemoryBarrierAcquireFunction](SDL_MemoryBarrierAcquireFunction.html)
- [SDL_MemoryBarrierReleaseFunction](SDL_MemoryBarrierReleaseFunction.html)
- [SDL_SetAtomicInt](SDL_SetAtomicInt.html)
- [SDL_SetAtomicPointer](SDL_SetAtomicPointer.html)
- [SDL_SetAtomicU32](SDL_SetAtomicU32.html)
- [SDL_TryLockSpinlock](SDL_TryLockSpinlock.html)
- [SDL_UnlockSpinlock](SDL_UnlockSpinlock.html)

## Datatypes

- [SDL_SpinLock](SDL_SpinLock.html)

## Structs

- [SDL_AtomicInt](SDL_AtomicInt.html)
- [SDL_AtomicU32](SDL_AtomicU32.html)

## Enums

- (none.)

## Macros

- [SDL_AtomicDecRef](SDL_AtomicDecRef.html)
- [SDL_AtomicIncRef](SDL_AtomicIncRef.html)
- [SDL_CompilerBarrier](SDL_CompilerBarrier.html)
- [SDL_CPUPauseInstruction](SDL_CPUPauseInstruction.html)
- [SDL_MemoryBarrierAcquire](SDL_MemoryBarrierAcquire.html)
- [SDL_MemoryBarrierRelease](SDL_MemoryBarrierRelease.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
