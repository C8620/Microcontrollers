; ============================================================================
;           COMP227 AY2022/23 Exercise 5
; Author:   Yang Hu
; Uni ID:   10827802
; Date:     Not yet completed
; Email:    yang.hu-6@student.manchester.ac.uk; yanghu22@acm.org
; ============================================================================



;=============================================================================
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
; System Stack Memory
stack       DEFS    128
stack_top   DEFW    0                           ; First unused location od stacks

; ----------------------------------------------
; function SVC_switch: handle SVC calls and invoke actions.
SVC_switch  PUSH    {LR, R0-R1}                    ; Protect registers - restore on exit.
            LDR     R0, [LR, #-4]               ; Load calling SVC instruction.
            LDR     R1, op_remove               ;
            AND     R0, R0, R1                  ; Remove the SVC instruction.
            CMP     R0, #9                      ; Check if mapping exist.
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
            DEFW    read_clock                  ; SVC 5: Get clock's value from R0.
            DEFW    timer_start                 ; SVC 6: Start a timer that occupy R6.
            DEFW    timer_end                   ; SVC 7: Unset the timer started by SVC 6.
            DEFW    read_butt                   ; SVC 8: Read values from buttons to R0.
            ALIGN                               ; Prevent anything out of order.
SVC_default B       SVC_default                 ; No mapping.

SVC_HALT    LDR     R0, HALT_PORT               ; Load address of halt port.
            STRB    R0, [R0]                    ; Write to halt port.

; ----------------------------------------------
; function IRQ_entry: handle IRQ calls and invoke actions.
IRQ_entry   PUSH    {LR, R0-R1}                 ; Protect registers - restore on exit.
            LDR     R0, IRQ_Request             ; Load the IRQ request.
            MOV     R1, #&00000001              ; Load the bit 0.
            AND     R0, R0, R1                  ; Check if bit 0 is High.
            CMP     R0, #&00000001              ; Compare the result.
            BLEQ    IRQ_clock                   ; If bit 0 is 1, run clock.
            MOV     R1, #&01000000              ; Load the bit 6.
            AND     R0, R0, R1                  ; Check if bit 6 is 1.
            CMP     R0, #&01000000              ; Compare the result.
            BLEQ    IRQ_ubutton                 ; If bit 6 is 1, run upper button.
            MOV     R1, #&10000000              ; Load the bit 7.
            AND     R0, R0, R1                  ; Check if bit 7 is 1.
            CMP     R0, #&10000000              ; Compare the result.
            BLEQ    IRQ_lbutton                 ; If bit 7 is 1, run lower button.
            POP     {LR, R0-R1}                 ; Restore user memory.
            MOVS    PC, LR                      ; Exit service mode.    

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
op_remove   DEFW    &00FF_FFFF

; ----------------------------------------------
; function lcd_reset: reset the display.
lcd_reset   PUSH    {LR, R9-R12}
            BL      lcd_idle
            LDR     R9, port_b                  ; Read current control values
            LDRB    R11, [R9]                   
            BIC     R11, R11, #:00000110        ; Change RS = 0, R/W = 0 (Write)
            STRB    R11, [R9]                   ; Write new control values
            LDR     R10, port_a                 ; Load address for PORT A
            MOV     R12, #:00000001             ; Load reset instruction to R12
            STRB    R12, [R10]                  ; Save instruction to port A
            BL      bus_on                      ; Commit changes
            BL      bus_off                     ; Reset state.
            POP     {LR, R9-R12}
            MOV     PC, LR

; ----------------------------------------------
; function lcd_chglne: Change the cursor to the start the another line of the LCD.
lcd_chglne  PUSH    {LR, R9-R12}
            BL      lcd_idle                    ; Wait until idle.
            LDR     R9, port_b                  ; Read current control values
            LDRB    R11, [R9]                   
            BIC     R11, R11, #:00000010        ; Change RS  = 0
            ORR     R11, R11, #:00000100        ; Change R/W = 1 (Read)
            STRB    R11, [R9]                   ; Write new control values
            BL      bus_on                      ; Enable Bus
            LDR     R10, port_a                 ; Read status byte to R12
            LDRB    R12, [R10]
            BL      bus_off  
            EOR     R12, R12, #:01000000        ; Change line bit.
            BIC     R12, R12, #:10111111        ; Leave only line bit.
            ORR     R12, R12, #:10000000        ; Change first bit as 1.

            BL      lcd_idle                    ; Wait until idle                
            BIC     R11, R11, #:00000110        ; Change RS = 0, R/W = 0 (Write)
            STRB    R11, [R9]                   ; Write new control values
            STRB    R12, [R10]                  ; Save instruction to port A
            BL      bus_on                      ; Commit changes
            BL      bus_off                     ; Reset state.
            POP     {LR, R9-R12}
            MOV     PC, LR

; ----------------------------------------------
; function lcd_lnehad: put cursor to the start of the current line.
lcd_lnehad  PUSH    {LR, R9-R12}
            BL      lcd_idle                    ; Wait until idle.
            LDR     R9, port_b                  ; Read current control values
            LDRB    R11, [R9]                   
            BIC     R11, R11, #:00000010        ; Change RS  = 0
            ORR     R11, R11, #:00000100        ; Change R/W = 1 (Read)
            STRB    R11, [R9]                   ; Write new control values
            BL      bus_on                      ; Enable Bus
            LDR     R10, port_a                 ; Read status byte to R12
            LDRB    R12, [R10]
            BL      bus_off  
            BIC     R12, R12, #:10111111        ; Leave only line bit.
            ORR     R12, R12, #:10000000        ; Change first bit as 1.

            BL      lcd_idle                    ; Wait until idle                
            BIC     R11, R11, #:00000110        ; Change RS = 0, R/W = 0 (Write)
            STRB    R11, [R9]                   ; Write new control values
            STRB    R12, [R10]                  ; Save instruction to port A
            BL      bus_on                      ; Commit changes
            BL      bus_off                     ; Reset state.
            POP     {LR, R9-R12}
            MOV     PC, LR

; ----------------------------------------------
; function lcd_prints:  print a string pointed by R10. R10 is memory location. String must end with 0.
lcd_prints  PUSH    {R10-R14}
            MOV     R11, R10
lcd_p_loop  LDR     R10, [R11]
            CMP     R10, #0
            BEQ     lcd_p_exit
            BL      lcd_printc
            ADD     R11, R11, #4
            B       lcd_p_loop
lcd_p_exit  POP     {R10-R14}
            MOV     PC, LR

; ----------------------------------------------
; function lcd_printc:  print a string pointed by R10. R10 is memory location. String must end with 0.
lcd_printc  PUSH    {R10-R14}
            CMP     R10, #&0D                   ; Carriage Return
            ADREQ   LR, lcp_pc_end              ; Set end of this function to LR.
            BEQ     lcd_chglne                  ; Request a line change.
            CMP     R10, #&0A                   ; Newline
            ADREQ   LR, lcp_pc_end              ; Set end of this function to LR.
            BEQ     lcd_chglne                  ; Request a line change.
            BL      lcd_write                   ; Good character, print!
lcp_pc_end  POP     {R10-R14}
            MOV     PC, LR

; ----------------------------------------------
; function lcd_lights: turn on the backlight of the LCD
lcd_lights  PUSH    {R9, R11}
            LDR     R9, port_b                  ; Read current control values
            LDRB    R11, [R9]
            ORR     R11, R11, #:00100000        ; Set Backlight to High, preserve everything else.
            STRB    R11, [R9]                   ; Write new control values
            POP     {R9, R11}
            MOV     PC, LR                      ; Return

; ----------------------------------------------
; function lcd_idle: wait until lcd is not busy.
lcd_idle    PUSH    {LR, R9, R11, R12}
            LDR     R9, port_b                  ; Read current control values
            LDRB    R11, [R9]                   
            BIC     R11, R11, #:00000010        ; Change RS  = 0
            ORR     R11, R11, #:00000100        ; Change R/W = 1 (Read)
            STRB    R11, [R9]                   ; Write new control values
            BL      bus_on                      ; Enable Bus
            LDR     R9, port_a                  ; Read status byte
            LDRB    R12, [R9]                   
            BL      bus_off                     ; Disable Bus
            BIC     R12, R12, #:01111111        ; Get only bit 7 of status byte
            CMP     R12, #:10000000             ; Is bit 7 of status byte high?
            BEQ     li_s2                       ; Yes, check again
            POP     {LR, R9, R11, R12}
            MOV     PC, LR                      ; No, LCD is idle now. Return.

; ----------------------------------------------
; function lcd_write: write the character given by R10 to LCD.
lcd_write   PUSH    {LR, R8-R11}
            BL      lcd_idle                    ; Step 1-5, wait until idle.
            LDR     R9, port_b                  ; Read current control values
            LDRB    R11, [R9]             
            ORR     R11, R11, #:00000010        ; Change RS  = 1
            BIC     R11, R11, #:00000100        ; Change R/W = 0 (Write)
            STRB    R11, [R9]                   ; Write new control byte to Data.
            LDR     R8, port_a                  ; Write data byte to data bus.
            STRB    R10, [R8]
            BL      bus_on
            BL      bus_off
            POP     {LR, R8-R11}
            MOV     PC, LR                      ; Returns

; ----------------------------------------------
; function bus_on: enable bus
bus_on      PUSH    {R9, R11}
            LDR     R9, port_b                  ; Read current control values
            LDRB    R11, [R9]             
            ORR     R11, R11, #:00000001        ; Set E to High, preserve everything else.
            STRB    R11, [R9]                   ; Write new control values
            POP     {R9, R11}
            MOV     PC, LR                      ; Return

; ----------------------------------------------
; function bus_off: disable bus
bus_off     PUSH    {R9, R11}
            LDR     R9, port_b                  ; Read current control values
            LDRB    R11, [R9]             
            BIC     R11, R11, #:00000001        ; Set E to Low, preserve everything else.
            STRB    R11, [R9]                   ; Write new control values
            POP     {R9, R11}
            MOV     PC, LR                      ; Return

; ----------------------------------------------
; function read_clock: Store timer's value into R0.
read_clock  PUSH    {R1}                        ; Register protection
            LDR     R1, clock                   ; Read current timer value
            LDRB    R0, [R1]                    ;
            POP     {R1}                        ; Restore register
            MOV     PC, LR                      ; Return

; ----------------------------------------------
; function timer_start: Set Timer Compare to start timer.
timer_start PUSH    {R1-R2}                     ; Register protection
            LDR     R1, clock_cmp               ; Load address.
            MOV     R2, #:00000000              ; Set TC interrupt at end of cycle.
            STRB    R2, [R1]                    ; Store this value.
            LDR     R1, IRQ_Swi                 ; Enable Interrupt for TC.
            LDRB    R2, [R1]                    ; Read current Enable value
            ORR     R2, R2, #:00000001          ; Enable TC interrupt
            STRB    R2, [R1]                    ; Store updated Enable value.
            MOV     R2, #:00000000              ; Set current timer value to 0.
            LDR     R1, clock                   ; Load address.
            STRB    R2, [R1]                    ; Store this value.
            POP     {R1-R2}                     ; Restore register.
            MOV     PC, LR                      ; Return

; ----------------------------------------------
; function timer_stop: Set Timer Compare to stop timer.
timer_stop  PUSH    {R1-R2}                     ; Register protection
            LDR     R1, IRQ_Swi                 ; Disable Interrupt for TC.
            LDRB    R2, [R1]                    ; Read current Enable value
            BIC     R2, R2, #:00000001          ; Disable TC interrupt
            STRB    R2, [R1]                    ; Store updated Enable value.
            LDR     R1, clock                   ; Read any extra value.
            LDRB    R2, [R1]                    ; Read current timer value
            ADD     R6, R2, R6                  ; Add to total time.
            POP     {R1-R2}                     ; Restore register.
            MOV     PC, LR                      ; Return

; ----------------------------------------------
; function read_butt: Read button's pressing state to R0.
read_butt   PUSH    {R1}                        ; Register protection.
            LDR     R1, button                  ; Read data incl. button.
            LDRB    R0, [R1]                    ; Read from memory.
            BIC     R0, R0, #:00110111          ; Filter out unneeded data.
            POP     {R1}                        ; Restore register
            MOV     PC, LR                      ; Return.
            ; Note on button mapping:
            ; Lower button on bit 7 (10000000),
            ; Upper button on bit 6 (01000000), and
            ; Extra button on but 3 (00001000).

IRQ_clock   ADD     R6, R6, #256                ; Add one cycle to the clock
            MOV     PC, LR                      ; Return

; ============================================================================
; USER INSTRUCION, MEMORY, AND PROGRAMS.
APPLICATION ADR     SP, usrStackTop             ; Initialise the User Stack
            SVC     4                           ; Reset the LCD unit. Clear everything.
            SVC     3                           ; Light up the LCD unit.
            ADR     R10, usrStr                 ; Load the address of the user String.
            SVC     2                           ; Print string.
            SVC     0                           ; Everything. Bye!

            CMP     R8, #6                      ; Check if mapping exist.
illegalStat BHI     illegalStat                 ; No mapping - run default.
            ADR     R1, stateSwitch             ; Load starting point of jump table
            ADR     LR, appStateLoop            ; Load return address - application loop.
            LDR     PC, [R1, R8, LSL #2]        ; Load corresponding address.

stateSwitch DEFW    statePending                ; State 0: Pending, waiting to start.
            DEFW    stateOngoing                ; State 1: Ongoing, waiting to stop.
            DEFW    stateStopped                ; State 2：Stopped, waiting to reset/start.
            DEFW    stateReseting               ; State 3: Reseting, reset once 1 second is reached.
            ALIGN                               ; Prevent anything out of order.

usrStr      DB      "Press any button to start", 0

; ----------------------------------------------
; User Stack Memory
usrStack    DEFS    32
usrStackTop DEFW    0                           ; First unused location od stack
