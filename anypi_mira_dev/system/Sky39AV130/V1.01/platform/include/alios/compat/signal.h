#ifndef CELESTIA_AOS_SIGNAL_H
#define CELESTIA_AOS_SIGNAL_H
#include_next <signal.h>
#include <stdint.h>

#ifndef __sigset_t_defined
typedef unsigned long sigset_t;
#define __sigset_t_defined
#endif

#ifndef __siginfo_t_defined
#define __siginfo_t_defined
typedef struct {
    int si_signo;
    int si_code;
    void *si_addr;
} siginfo_t;
#endif

#ifndef SA_SIGINFO
#define SA_SIGINFO 4
#endif

struct sigaction {
    union {
        void (*sa_handler)(int);
        void (*sa_sigaction)(int, siginfo_t *, void *);
    };
    sigset_t sa_mask;
    int sa_flags;
};

int sigaction(int signum, const struct sigaction *act, struct sigaction *oldact);

static inline int sigemptyset(sigset_t *set)
{
    if (set)
        *set = 0;
    return 0;
}

#endif

