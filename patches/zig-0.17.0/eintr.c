#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <sys/wait.h>

pid_t wait4(pid_t pid, int *status, int options, struct rusage *usage) {
    static pid_t interrupted;
    static int retried;
    pid_t (*next)(pid_t, int *, int, struct rusage *) = dlsym(RTLD_NEXT, "wait4");
    if (!next) abort();
    if (pid > 0 && interrupted == 0) {
        interrupted = pid;
        fprintf(stderr, "EINTR_INJECTED pid=%d\n", pid);
        errno = EINTR;
        return -1;
    }
    if (pid == interrupted && !retried) {
        retried = 1;
        fprintf(stderr, "EINTR_RETRIED pid=%d\n", pid);
    }
    return next(pid, status, options, usage);
}
