/*
 * Minimal C11 <threads.h> shim for Darwin (macOS), built on <pthread.h>.
 *
 * Apple's libSystem has never shipped C11 <threads.h>, on macOS 10.6
 * through the current SDKs. This header covers only the subset of the
 * API that foot (https://codeberg.org/dnkl/foot) and its fcft
 * subproject actually use: thrd_create/thrd_join/thrd_t,
 * mtx_init/mtx_lock/mtx_unlock/mtx_destroy/mtx_t/mtx_plain,
 * cnd_init/cnd_wait/cnd_signal/cnd_broadcast/cnd_destroy/cnd_t, and
 * the thrd_* status enum. It does not implement tss_*,
 * call_once/once_flag, mtx_timedlock/mtx_trylock, recursive or timed
 * mutexes, cnd_timedwait, or thrd_detach/sleep/yield/current/equal/
 * exit.
 *
 * Unlike FreeBSD's libstdthreads (where pthread_mutex_t/pthread_cond_t
 * are themselves opaque pointers), Darwin's pthread_mutex_t and
 * pthread_cond_t are by-value opaque structs, so mtx_t/cnd_t alias
 * them directly instead of wrapping a pointer.
 */
#pragma once

#include <pthread.h>

typedef pthread_t thrd_t;
typedef pthread_mutex_t mtx_t;
typedef pthread_cond_t cnd_t;

typedef int (*thrd_start_t)(void *);

enum {
    mtx_plain = 0x1,
    mtx_recursive = 0x2,
    mtx_timed = 0x4
};

enum {
    thrd_success = 0,
    thrd_busy,
    thrd_error,
    thrd_nomem,
    thrd_timedout
};

#ifdef __cplusplus
extern "C" {
#endif

int thrd_create(thrd_t *thr, thrd_start_t func, void *arg);
int thrd_join(thrd_t thr, int *res);

int mtx_init(mtx_t *mtx, int type);
int mtx_lock(mtx_t *mtx);
int mtx_unlock(mtx_t *mtx);
void mtx_destroy(mtx_t *mtx);

int cnd_init(cnd_t *cond);
int cnd_signal(cnd_t *cond);
int cnd_broadcast(cnd_t *cond);
int cnd_wait(cnd_t *cond, mtx_t *mtx);
void cnd_destroy(cnd_t *cond);

#ifdef __cplusplus
}
#endif
