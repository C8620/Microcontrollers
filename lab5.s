; ============================================================================
;           COMP227 AY2022/23 Exercise 5
; Author:   Yang Hu
; Uni ID:   10827802
; Date:     Not yet completed
; Email:    yang.hu-6@student.manchester.ac.uk; yanghu22@acm.org
; ============================================================================
; NOTE:     This lab 5 submission is already interrupt-based. This is because
;           When I was asking for some questions, an lecture of interrupt was
;           given and the code was therefore transformed into an interrupt-
;           based code instead of non-interrupt approach.
; ============================================================================


; ============================================================================
; SYSTEM INSTRUCTIONS, MEMORY, AND OPERAION HANDLING.

            ADR     SP, stack_top               ; Initialise the Supervisor Stack
            B       INIT_user                   ; Head to the initialisation section
SVC_entry   B       SVC_switch                  ; SVC call
pref_abrt   B       pref_abrt                   ; Prefetch abort
data_abrt   B       data_abrt                   ; Data abort
            MOV     R0, R0                      ;
            B       IRQ_entry                   ; Interrupt
FIQ_entry   B       FIQ_entry                   ; Fast interrupt

INIT_user   MOV     R0, #&D0                    ; User mode, no ints.
            MSR     SPSR, R0                    ;
            ADRL    R0, APPLICATION             ; Load user code address
            MOVS    PC, R0                      ; ‘Return’ to user code

fin         B       fin                         ; Infinite loop. Halt.

; ----------------------------------------------
; System SVP Stack Memory
stack       DEFS    128
stack_top   DEFW    0                           ; First unused location od stacks
timer_mem   DEFW    &0000_0000                  ; Timer memory.

; ============================================================================
; SVC CALL HANDLING AND FUNCTIONS. COULD BE USED BY INTERRUPTS.

; ----------------------------------------------
; function SVC_switch: handle SVC calls and invoke actions.
SVC_switch  PUSH    {LR, R0-R1}                    ; Protect registers - restore on exit.
            LDR     R0, [LR, #-4]               ; Load calling SVC instruction.
            LDR     R1, op_remove               ;
            AND     R0, R0, R1                  ; Remove the SVC instruction.
            CMP     R0, #6                      ; Check if mapping exist.
            BHI     SVC_default                 ; No mapping - run default.
            ADR     R1, SVC_funcs               ; Load starting point of jump table
            ADR     LR, SVC_exit                ; Load return address- SVC_exit
            LDR     PC, [R1, R0, LSL #2]        ; Load corresponding address.

SVC_exit    POP     {LR, R0-R1}                 ; Restore user memory.
            MOVS    PC, LR                      ; Exit service mode.
SVC_funcs   DEFW    SVC_HALT                    ; SVC 0: Exit, write to halt port.
            DEFW    lcd_printc                  ; SVC 1: Print character in R10.
            DEFW    lcd_prints                  ; SVC 2: Print string pointed by R10.
            DEFW    lcd_lights                  ; SVC 3: Trun on the LCD backlight.
            DEFW    lcd_reset                   ; SVC 4: Reset the LCD.
            DEFW    read_timer                  ; SVC 5: Have timer's count saved to R0.
            DEFW    timer_arm                   ; SVC 6: Arm the timer, ready to start.
            ALIGN                               ; Prevent anything out of order.
SVC_default B       SVC_default                 ; No mapping.

SVC_HALT    LDR     R0, HALT_PORT               ; Load address of halt port.
            STRB    R0, [R0]                    ; Write to halt port.

; ----------------------------------------------
; Static memory pointers used by SVC/IRQ programs.
port_a      DEFW    &1000_0000
port_b      DEFW    &1000_0004
button      DEFW    &1000_0004
clock       DEFW    &1000_0008
clock_cmp   DEFW    &1000_000C
IRQ_Req     DEFW    &1000_0018
IRQ_Swi     DEFW    &1000_001C
HALT_PORT   DEFW    &1000_0020

; ----------------------------------------------
; Static operations used by SVC/IRQ programs.
op_remove   DEFW    &00FF_FFFF

; ----------------------------------------------
; function lcd_reset: reset the display.
lcd_reset   PUSH    {LR, R9-R12}                ; Protect registers.
            BL      lcd_idle                    ; Wait until LCD is idle
            LDR     R9, port_b                  ; Read control value memory addr.
            LDRB    R11, [R9]                   ; Load values to R11.
            AND     R11, R11, #:11111001        ; Change RS = 0, R/W = 0 (Write)
            STRB    R11, [R9]                   ; Write new control values
            LDR     R10, port_a                 ; Load address for PORT A
            MOV     R12, #:00000001             ; Load reset instruction to R12
            STRB    R12, [R10]                  ; Save instruction to port A
            BL      bus_on                      ; Commit changes
            BL      bus_off                     ; Reset state.
            POP     {PC, R9-R12}                ; Restore registers and return.

; ----------------------------------------------
; function lcd_chglne: Change the cursor to the start the another line of the LCD.
lcd_chglne  PUSH    {LR, R9-R12}                ; Protect registers.
            BL      lcd_idle                    ; Wait until idle.
            LDR     R9, port_b                  ; Read control value memory addr.
            LDRB    R11, [R9]                   ; Load values to R11.
            AND     R11, R11, #:11111101        ; Change RS  = 0
            ORR     R11, R11, #:00000100        ; Change R/W = 1 (Read)
            STRB    R11, [R9]                   ; Write new control values
            BL      bus_on                      ; Enable Bus
            LDR     R10, port_a                 ; Read status byte memory addr.
            LDRB    R12, [R10]                  ; Load current status to R12.
            BL      bus_off                     ; Disable Bus.
            EOR     R12, R12, #:01000000        ; Change line bit.
            AND     R12, R12, #:01000000        ; Leave only line bit.
            ORR     R12, R12, #:10000000        ; Change first bit as 1.

            BL      lcd_idle                    ; Wait until idle                
            AND     R11, R11, #:11111001        ; Change RS = 0, R/W = 0 (Write)
            STRB    R11, [R9]                   ; Write new control values
            STRB    R12, [R10]                  ; Save instruction to port A
            BL      bus_on                      ; Commit changes
            BL      bus_off                     ; Reset state.
            POP     {PC, R9-R12}                ; Restore registers and return.

; ----------------------------------------------
; function lcd_lnehad: put cursor to the start of the current line.
lcd_lnehad  PUSH    {LR, R9-R12}                ; Protect registers
            BL      lcd_idle                    ; Wait until idle.
            LDR     R9, port_b                  ; Read control values memory addr.
            LDRB    R11, [R9]                   ; Read current values to R11.
            AND     R11, R11, #:11111110        ; Change RS  = 0
            ORR     R11, R11, #:00000100        ; Change R/W = 1 (Read)
            STRB    R11, [R9]                   ; Write new control values
            BL      bus_on                      ; Enable Bus
            LDR     R10, port_a                 ; Read status byte memory addr.
            LDRB    R12, [R10]                  ; Read current value to R12.
            BL      bus_off                     ; Disable bus.
            AND     R12, R12, #:01000000        ; Leave only line bit.
            ORR     R12, R12, #:10000000        ; Change first bit as 1.

            BL      lcd_idle                    ; Wait until idle                
            AND     R11, R11, #:11111001        ; Change RS = 0, R/W = 0 (Write)
            STRB    R11, [R9]                   ; Write new control values
            STRB    R12, [R10]                  ; Save instruction to port A
            BL      bus_on                      ; Commit changes
            BL      bus_off                     ; Reset state.
            POP     {PC, R9-R12}                ; Restore registers and return.

; ----------------------------------------------
; function lcd_prints:  print a string pointed by R10. R10 is memory location. String must end with 0.
lcd_prints  PUSH    {LR, R10-R11}               ; Protect registers.
lcd_p_loop  LDR     R11, [R10]                  ; Load value from R10 address.
            CMP     R11, #0                     ; Is the string ending?
            BEQ     lcd_p_exit                  ; Yes, prepare return!
            BL      lcd_printc                  ; No, print this character.
            ADD     R10, R10, #4                ; Point R10 to next space.
            B       lcd_p_loop                  ; Process next character.
lcd_p_exit  POP     {LR, R10-R11}               ; Restore registers and return.

; ----------------------------------------------
; function lcd_printc:  print a string pointed by R10. R10 is memory location. String must end with 0.
lcd_printc  PUSH    {LR, R10}                   ; Protect registers
            CMP     R10, #&0D                   ; Carriage Return
            ADREQ   LR, lcp_pc_end              ; Set end of this function to LR.
            BEQ     lcd_chglne                  ; Request a line change.
            CMP     R10, #&0A                   ; Newline
            ADREQ   LR, lcp_pc_end              ; Set end of this function to LR.
            BEQ     lcd_chglne                  ; Request a line change.
            BL      lcd_write                   ; Good character, print!
lcp_pc_end  POP     {PC, R10}                   ; Restore registers and return.

; ----------------------------------------------
; function lcd_lights: turn on the backlight of the LCD
lcd_lights  PUSH    {R9, R11}                   ; Protect registers
            LDR     R9, port_b                  ; Read control values memory addr.
            LDRB    R11, [R9]                   ; Read current values to R11.
            ORR     R11, R11, #:00100000        ; Set Backlight to High, preserve everything else.
            STRB    R11, [R9]                   ; Write new control values
            POP     {R9, R11}                   ; Restore registers
            MOV     PC, LR                      ; Return

; ----------------------------------------------
; function lcd_idle: wait until lcd is not busy.
lcd_idle    PUSH    {LR, R9, R11, R12}          ; Protect registers
            LDR     R9, port_b                  ; Read control values memory addr.
            LDRB    R11, [R9]                   ; Read current values to R11.
            AND     R11, R11, #:11111101        ; Change RS  = 0
            ORR     R11, R11, #:00000100        ; Change R/W = 1 (Read)
            STRB    R11, [R9]                   ; Write new control values
lcd_idle_l  BL      bus_on                      ; Enable Bus
            LDR     R9, port_a                  ; Read status byte memory addr.
            LDRB    R12, [R9]                   ; Read current value to R12.
            BL      bus_off                     ; Disable Bus
            AND     R12, R12, #:10000000        ; Get only bit 7 of status byte
            CMP     R12, #:10000000             ; Is bit 7 of status byte high?
            BEQ     lcd_idle_l                  ; Yes, check again
            POP     {PC, R9, R11, R12}          ; No, LCD is idle now. Return.
                                                ; Restore registers and return.                

; ----------------------------------------------
; function lcd_write: write the character given by R10 to LCD.
lcd_write   PUSH    {LR, R8-R11}                ; Protect registers.
            BL      lcd_idle                    ; Step 1-5, wait until idle.
            LDR     R9, port_b                  ; Read control values memory addr.
            LDRB    R11, [R9]                   ; Read current values to R11.
            ORR     R11, R11, #:00000010        ; Change RS  = 1
            AND     R11, R11, #:11111011        ; Change R/W = 0 (Write)
            STRB    R11, [R9]                   ; Write new control byte to Data.
            LDR     R8, port_a                  ; Load data bus memory addr.
            STRB    R10, [R8]                   ; Write data byte to data bus.
            BL      bus_on                      ; Enable bus to apply changes.
            BL      bus_off                     ; Disable bus.
            POP     {PC, R8-R11}                ; Restore registers and return.

; ----------------------------------------------
; function bus_on: enable bus
bus_on      PUSH    {R9, R11}                   ; Protect registers.
            LDR     R9, port_b                  ; Load control values memory addr.
            LDRB    R11, [R9]                   ; Read current values to R11.
            ORR     R11, R11, #:00000001        ; Set E to High, preserve everything else.
            STRB    R11, [R9]                   ; Write new control values
            POP     {R9, R11}                   ; Restore registers.
            MOV     PC, LR                      ; Return

; ----------------------------------------------
; function bus_off: disable bus
bus_off     PUSH    {R9, R11}                   ; Protect registers
            LDR     R9, port_b                  ; Load control values memory addr.
            LDRB    R11, [R9]                   ; Read current values to R11.
            AND     R11, R11, #:11111110        ; Set E to Low, preserve everything else.
            STRB    R11, [R9]                   ; Write new control values
            POP     {R9, R11}                   ; Restore registers.
            MOV     PC, LR                      ; Return

; ----------------------------------------------
; function read_timer: Have timer memory's value loaded to R0.
read_timer  LDR     R0, timer_mem               ; Have timer mem loaded into R0.
            MOV     PC, LR                      ; Return

; ----------------------------------------------
; function timer_arm: Prepare the system for a start of counting.
;                     This function would allow LButton interrupt to occur.
timer_arm   PUSH    {R0-R1}                     ; Register protection
            MOV     R1, #0                      ; Reset timer memory to 0.
            STR     R1, timer_mem               ; Load 0 to timer memory.
            MRS     R1, SPSR                    ; Set I bit of SPSR to low.
            AND     R1, R1, #:01111111          ; Modify I bit to LOW.
            MSR     SPSR_c, R1                  ; Store updated value.
            LDR     R0, IRQ_Swi                 ; Enable Interrupt for low button
            LDRB    R1, [R0]                    ; Read current Interrupt switches
            ORR     R1, R1, #:10000000          ; Enable for Lower Button.
            STRB    R1, [R0]                    ; Store updated value.
            POP     {R0-R1}                     ; Register Protection
            MOV     PC, LR                      ; Return

; ============================================================================
; INTERRUPT HANDLING AND FUNCTIONS

; ----------------------------------------------
; function IRQ_entry: handle IRQ calls and invoke actions.
IRQ_entry   ADR     SP, stack_top               ; Initialise the Interrupt Stack
            PUSH    {LR, R0-R3}                 ; Protect registers - restore on exit.
            LDR     R3, IRQ_Req                 ; Load the IRQ request's memory addr.
            LDRB    R0, [R3]                    ; Load IRQ Request data
            AND     R1, R0, #:00000001          ; Leave only bit 0
            CMP     R1, #:00000000              ; Compare the result.
            BLNE    IRQ_clock                   ; If bit 0 is 1, run clock (Time interrupt).
            AND     R1, R0, #:01000000          ; Leave only bit 6
            CMP     R1, #:00000000              ; Compare the result.
            BLNE    IRQ_ubutoon                 ; If bit 6 is 1, run UPPER button.
            AND     R1, R0, #:00100000          ; Leave only bit 5
            CMP     R1, #:00000000              ; Compare the result.
            BLNE    timer_start                 ; If bit 5 is 1, run LOWER button.
            AND     R0, R0, #:00111110          ; Clear bit 0, 6, and 7.
            STRB    R0, [R3]                    ; Store new interrupt requests.
            POP     {LR, R0-R3}                 ; Restore registers.
            MOVS    PC, LR                      ; Return.

; ----------------------------------------------
; function IRQ_ubutoon: Handle interrupt request led by upper button.
IRQ_ubutoon PUSH    {LR, R0}                    ; Protect registers.
            LDR     R0, IRQ_Swi                 ; Load IRQ switches address.
            LDRB    R0, [R0]                    ; Load IRQ switches values.
            AND     R0, R0, #:00000001          ; Leave only bit 0.
            LDR     LR, IRQ_ubtn_e              ; Set return address.
            CMP     R0, #:00000001              ; If time interrupt is HIGH?
            BEQ     timer_stop                  ; Yes, stop timer.
            BNE     timer_reset                 ; No, possible reset!
IRQ_ubtn_e  POP     {PC, R0}                    ; Restore registers and return.


; ----------------------------------------------
; function timer_start: Set Timer Compare to start timer.
timer_start PUSH    {R1-R2}                     ; Register protection
            LDR     R1, clock_cmp               ; Load address.
            MOV     R2, #100                    ; Set TC interrupt at 100ms later.
            STRB    R2, [R1]                    ; Store this value.
            MOV     R2, #:00000000              ; Set current timer value to 0.
            LDR     R1, clock                   ; Load address.
            STRB    R2, [R1]                    ; Store this value.
            LDR     R1, IRQ_Swi                 ; Enable Interrupt for TC.
            LDRB    R2, [R1]                    ; Read current Enable value
            AND     R2, R2, #:01111111          ; Disable LowButton interrup (this)
            ORR     R2, R2, #:01000001          ; Enable TC and UpButton interrupt
            STRB    R2, [R1]                    ; Store updated Enable value.
            POP     {R1-R2}                     ; Restore register.
            MOV     PC, LR                      ; Return

; ----------------------------------------------
; function timer_stop: Set Timer Compare to stop timer.
timer_stop  PUSH    {R1-R2}                     ; Register protection
            LDR     R1, IRQ_Swi                 ; Disable Interrupt for TC:
            LDRB    R2, [R1]                    ; Read current Enable value
            AND     R2, R2, #:11111110          ; Set TC interrupt bit to low.
            ORR     R2, R2, #:10000000          ; Enable LowButton interrupt (resume).
            STRB    R2, [R1]                    ; Store updated Enable value.
            POP     {R1-R2}                     ; Restore register.
            MOV     PC, LR                      ; Return

; ----------------------------------------------
; function timer_reset: If the UButton is pressed for more than 1000ms, reset timer
timer_reset PUSH    {R1-R2}                     ; Register protection

            POP     {R1-R2}                     ; Register restoration
            MOV     PC, LR                      ; Return.

; ----------------------------------------------
; function read_butt: Read button's pressing state to R0. TO BE DELETED!
read_butt   PUSH    {R1}                        ; Register protection.
            LDR     R1, button                  ; Read data incl. button.
            LDRB    R0, [R1]                    ; Read from memory.
            AND     R0, R0, #:11001000          ; Filter out unneeded data.
            POP     {R1}                        ; Restore register
            MOV     PC, LR                      ; Return.
            ; Note on button mapping:
            ; Lower button on bit 7 (10000000),
            ; Upper button on bit 6 (01000000), and
            ; Extra button on but 3 (00001000).

; ----------------------------------------------
; function IRQ_clock: maintain time passed in R6 through TC interrupts.
IRQ_clock   PUSH    {R1, R2}                    ; Register protection.
            LDR     R1, timer_mem               ; Load current timer memory.
            ADD     R1, R1, #1                  ; Add 100ms that has passed.
            STR     R1, timer_mem               ; Store updated value to memory.
            LDR     R2, clock_cmp               ; Load TC address
            LDRB    R1, [R2]                    ; Load current TC value.
            ADD     R1, R1, #100                ; Set TC to 100ms later.
            CMP     R1, #256                    ; Larger than 256?
            SUBHI   R1, R1, #256                ; Yes. Must be set in next cycle.
            STRB    R1, [R2]                    ; Store updated value.
            POP     {R1, R2}                    ; Register restoration.
            MOV     PC, LR                      ; Return

; ============================================================================
; USER INSTRUCION, MEMORY, AND PROGRAMS.
APPLICATION ADR     SP, usrStackTop             ; Initialise the User Stack
            SVC     6                           ; Arm timer.
inf_loop    B       inf_loop                    ; Let interrupts do the rest!
            B       inf_loop                    ; Interrupt would return to here!
            SVC     0                           ; Everything. Bye!
            SVC     4                           ; Reset the LCD unit. Clear everything.
            SVC     3                           ; Light up the LCD unit.

usrStr      DEFW    "Press any button to start", 0

; ----------------------------------------------
; User Stack Memory
usrStack    DEFS    32
usrStackTop DEFW    0                           ; First unused location on stack