/* SPDX-License-Identifier: Apache-2.0 */
#ifndef CELESTIA_AOS_UCONTEXT_H
#define CELESTIA_AOS_UCONTEXT_H

/* Layout read by application/app_main/main.c on __arm__. */
typedef struct {
    struct {
        unsigned long arm_r0;
        unsigned long arm_r1;
        unsigned long arm_r2;
        unsigned long arm_r3;
        unsigned long arm_r4;
        unsigned long arm_r5;
        unsigned long arm_r6;
        unsigned long arm_r7;
        unsigned long arm_r8;
        unsigned long arm_r9;
        unsigned long arm_r10;
        unsigned long arm_ip;
        unsigned long arm_fp;
        unsigned long arm_sp;
        unsigned long arm_lr;
        unsigned long arm_pc;
    } uc_mcontext;
} ucontext_t;

#endif
