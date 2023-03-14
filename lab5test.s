; ============================================================================
;           COMP227 AY2022/23 Exercise 5 Test
; Author:   Yang Hu
; Uni ID:   10827802
; Date:     Monday, 14 March 2023
; Email:    yang.hu-6@student.manchester.ac.uk; yanghu22@acm.org
; ============================================================================



;=============================================================================
; SYSTEM INSTRUCTIONS, MEMORY, AND OPERAION HANDLING.

            MOV     R0, R0                      ; Initialise the Supervisor Stack
            B       INIT_user                   ; Head to the initialisation section
SVC_entry   B       SVC_entry                   ; SVC call
pref_abrt   B       pref_abrt                   ; Prefetch abort
data_abrt   B       data_abrt                   ; Data abort
            MOV     R0, R0                      ;
IRQ_entry   B       IRQ_entry                   ; Interrupt
FIQ_entry   B       FIQ_entry                   ; Fast interrupt

INIT_user   LDR     R0, IRQ_Req                 ; Clear IRQ Requests
            MOV     R1, #:00000000
            STRB    R1, [R0]
            LDR     R0, IRQ_Swi                 ; Enable Interrupt for buttons
            MOV     R1, #:11000000
            STRB    R1, [R0]
            MRS     R1, CPSR                    ; Set I bit of CPSR to low.
            BIC     R1, R1, #:10000000            
            MSR     CPSR_c, R1
fin         B       fin                         ; Infinite loop. Halt.

; ----------------------------------------------
; Static memory pointers used by SVC programs.
port_a      DEFW    &1000_0000
port_b      DEFW    &1000_0004
button      DEFW    &1000_0004
clock       DEFW    &1000_0008
clock_cmp   DEFW    &1000_000C
IRQ_Req     DEFW    &1000_0018
IRQ_Swi     DEFW    &1000_001C
HALT_PORT   DEFW    &1000_0020