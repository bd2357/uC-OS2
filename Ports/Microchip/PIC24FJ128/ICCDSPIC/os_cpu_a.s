;********************************************************************************************************
;                                              uC/OS-II
;                                        The Real-Time Kernel
;
;                    Copyright 1992-2020 Silicon Laboratories Inc. www.silabs.com
;
;                                 SPDX-License-Identifier: APACHE-2.0
;
;               This software is subject to an open source license and is distributed by
;                Silicon Laboratories Inc. pursuant to the terms of the Apache License,
;                    Version 2.0 available at www.apache.org/licenses/LICENSE-2.0.
;
;********************************************************************************************************

;********************************************************************************************************
;
;                                            Microchip PIC24
;                                               ICCDSPIC
;
; Filename : os_cpu_a.s
; Version  : V2.93.00
;********************************************************************************************************

;********************************************************************************************************
;                                            INCLUDES
;********************************************************************************************************

#include "io24fj128ga010.h"
#include "os_cpu_util_a.s59"

;********************************************************************************************************
;                                            LINKER SPECIFICS
;********************************************************************************************************

    RSEG CODE:CODE:NOROOT(2)

;********************************************************************************************************
;                                            CONSTANTS
;********************************************************************************************************

IPL3    EQU    0x0003

;********************************************************************************************************
;                                            GLOBALS
;********************************************************************************************************

    PUBLIC  OSStartHighRdy
    PUBLIC  OSCtxSw
    PUBLIC  OSIntCtxSw

;********************************************************************************************************
;                                            EXTERNALS
;********************************************************************************************************

    EXTERN  OSTCBCur
    EXTERN  OSTCBHighRdy
    EXTERN  OSPrioCur
    EXTERN  OSPrioHighRdy
    EXTERN  OSRunning
    EXTERN  OSTaskSwHook

;********************************************************************************************************
;                                            OSStartHighRdy
;
; Description : This function determines the highest priority task that is ready to run after
;               OSInit() is called.
;********************************************************************************************************

OSStartHighRdy:
    call   OSTaskSwHook                           ; Call user defined task switch hook

    mov    #0x0001, w0                            ; Set OSRunning to TRUE
    mov    #OSRunning, w1
    mov.b  w0, [w1]                               ; Set OSRunning to TRUE

                                                  ; Get stack pointer of the task to resume
    mov    OSTCBHighRdy, w0                       ; Get the pointer to the stack to resume
    mov    [w0], w15                              ; Dereference the pointer and store the data (the new stack address) W15, the stack pointer register

    OS_REGS_RESTORE                               ; Restore all of this tasks registers from the stack

    retfie                                        ; Return from the interrupt, the task is now ready to run

;********************************************************************************************************
;                                            OSCtxSw
;
; Description : TThe code to perform a 'task level' context switch.  OSCtxSw() is called
;               when a higher priority task is made ready to run by another task or,
;               when the current task can no longer execute (e.g. it calls OSTimeDly(),
;               OSSemPend() and the semaphore is not available, etc.).
;********************************************************************************************************

OSCtxSw:
                                                  ; TRAP (interrupt) should bring us here, not 'call'.
                                                  ; Since dsPIC has no TRAP, it is necessary to correct the stack to simulate an interrupt
                                                  ; In other words, this function must also save SR and IPL3 to the stack, not just the PC.

    mov.b  SR, wreg                               ; Load SRL
    sl w0, #8, w0                                 ; Shift left by 8
    btsc.b CORCON, #IPL3                          ; Test IPL3 bit, skip if clear
    bset   w0, #7;                                ; Copy IPL3 to bit7 of w0

    ior    w0, [--w15], w0                        ; Merge bits
    mov    w0, [w15++]                            ; Write back

    OS_REGS_SAVE                                  ; Save processor registers

                                                  ; Save current task's stack pointer into the currect tasks TCB
    mov    OSTCBCur, w0                           ; Get the address of the location in this tasks TCB to store the stack pointer
    mov    w15, [w0]                              ; Store the stack pointer in this tasks TCB

    call   OSTaskSwHook                           ; Call the user defined task switch hook

    mov    OSTCBHighRdy, w1                       ; Set the current running TCB to the TCB of the highest priority task ready to run
    mov    w1, OSTCBCur
    mov    #OSPrioHighRdy, w0
    mov    #OSPrioCur, w2
    mov.b  [w0], [w2]

    mov    [w1], w15                              ; Load W15 with the stack pointer from the task that is ready to run

    OS_REGS_RESTORE                               ; Restore registers

    retfie                                        ; Return from interrupt

;********************************************************************************************************
;                                            OSIntCtxSw
;
; Description : When an ISR (Interrupt Service Routine) completes, OSIntExit() is called to
;               determine whether a more important task than the interrupted task needs to
;               execute.  If that's the case, OSIntExit() determines which task to run next
;               and calls OSIntCtxSw() to perform the actual context switch to that task.
;********************************************************************************************************

OSIntCtxSw:
    call   OSTaskSwHook                           ; Call the user defined task switch hook

    mov    OSTCBHighRdy, w1                       ; Set the current running TCB to the TCB of the highest priority task ready to run
    mov    w1, OSTCBCur
    mov    #OSPrioHighRdy, w0
    mov    #OSPrioCur, w2
    mov.b  [w0], [w2]

    mov    [w1], w15                              ; Load W15 with the stack pointer from the task that is ready to run

    OS_REGS_RESTORE                               ; Restore registers

    retfie                                        ; Return from interrupt

    END


