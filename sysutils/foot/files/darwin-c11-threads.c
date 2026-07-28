#include "darwin-c11-threads.h"

#include <errno.h>
#include <stdint.h>
#include <stdlib.h>

struct thrd_trampoline_arg {
    thrd_start_t func;
    void *arg;
};

static void *
thrd_trampoline(void *arg)
{
    struct thrd_trampoline_arg ta = *(struct thrd_trampoline_arg *)arg;
    free(arg);
    return (void *)(intptr_t)ta.func(ta.arg);
}

int
thrd_create(thrd_t *thr, thrd_start_t func, void *arg)
{
    struct thrd_trampoline_arg *ta = malloc(sizeof(*ta));
    if (ta == NULL)
        return thrd_nomem;

    ta->func = func;
    ta->arg = arg;

    switch (pthread_create(thr, NULL, thrd_trampoline, ta)) {
    case 0:
        return thrd_success;
    case EAGAIN:
        free(ta);
        return thrd_nomem;
    default:
        free(ta);
        return thrd_error;
    }
}

int
thrd_join(thrd_t thr, int *res)
{
    void *retval;

    if (pthread_join(thr, &retval) != 0)
        return thrd_error;
    if (res != NULL)
        *res = (int)(intptr_t)retval;
    return thrd_success;
}

int
mtx_init(mtx_t *mtx, int type)
{
    if (type != mtx_plain)
        return thrd_error;
    return pthread_mutex_init(mtx, NULL) == 0 ? thrd_success : thrd_error;
}

int
mtx_lock(mtx_t *mtx)
{
    return pthread_mutex_lock(mtx) == 0 ? thrd_success : thrd_error;
}

int
mtx_unlock(mtx_t *mtx)
{
    return pthread_mutex_unlock(mtx) == 0 ? thrd_success : thrd_error;
}

void
mtx_destroy(mtx_t *mtx)
{
    (void)pthread_mutex_destroy(mtx);
}

int
cnd_init(cnd_t *cond)
{
    return pthread_cond_init(cond, NULL) == 0 ? thrd_success : thrd_error;
}

int
cnd_signal(cnd_t *cond)
{
    return pthread_cond_signal(cond) == 0 ? thrd_success : thrd_error;
}

int
cnd_broadcast(cnd_t *cond)
{
    return pthread_cond_broadcast(cond) == 0 ? thrd_success : thrd_error;
}

int
cnd_wait(cnd_t *cond, mtx_t *mtx)
{
    return pthread_cond_wait(cond, mtx) == 0 ? thrd_success : thrd_error;
}

void
cnd_destroy(cnd_t *cond)
{
    (void)pthread_cond_destroy(cond);
}
