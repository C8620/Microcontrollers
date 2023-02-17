; ============================================================================
;           COMP227 AY2022/23 Exercise 3
; Author:   Yang Hu
; Uni ID:   10827802
; Date:     Fri, 17 Feb 2023
; Email:    yang.hu-6@student.manchester.ac.uk; yanghu22@acm.org
; ============================================================================


; Capabilities:
; Basic:    Print given strings.
; Advanced: Print different strings on different lines of the Display.
;           With: Automatically detect current line and switch to another.
;                 Detect \n and \r in strings, and preform a line change. 

; ----------------------------------------------
; MAIN PROGRAM

            ADR     SP, stack_top               ; Initialise the Stack
            BL      lcd_reset                   ; Reset the LCD unit. Clear everything.
            BL      lcd_lights                  ; Turn on the backlight on LCD, if not already.
            ADR     R10, str1                   ; Load the address of the String 1.
            BL      lcd_prints                  ; Print the String 1.
            BL      lcd_chglne                  ; Change to the other line.
            ADR     R10, str2                   ; Load the address of the String 2.
            BL      lcd_prints                  ; Print the String 2.
            BL      lcd_chglne                  ; Change to the other line.
        ; Printing of String 3 is commented, as it contains two lines and will overwrite previous strings.
            ;ADR     R10, str3                   ; Load the address of the String 3.
            ;BL      lcd_prints                  ; Print the String 2 in 2 lines.
            B       fin                         ; End of it! Bye!

; ----------------------------------------------
; function lcd_reset: reset the display.
lcd_reset   PUSH    {LR, R9-R12}
            BL      lcd_idle
            LDR     R9, port_b                  ; Read current control values
            LDRB    R11, [R9]                   
            AND     R11, R11, #:11111001        ; Change RS = 0, R/W = 0 (Write)
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
            AND     R11, R11, #:11111101        ; Change RS  = 0
            ORR     R11, R11, #:00000100        ; Change R/W = 1 (Read)
            STRB    R11, [R9]                   ; Write new control values
            BL      bus_on                      ; Enable Bus
            LDR     R10, port_a                 ; Read status byte to R12
            LDRB    R12, [R10]
            BL      bus_off  
            EOR     R12, R12, #:01000000        ; Change line bit.
            AND     R12, R12, #:01000000        ; Leave only line bit.
            ORR     R12, R12, #:10000000        ; Change first bit as 1.

            BL      lcd_idle                    ; Wait until idle                
            AND     R11, R11, #:11111001        ; Change RS = 0, R/W = 0 (Write)
            STRB    R11, [R9]                   ; Write new control values
            STRB    R12, [R10]                  ; Save instruction to port A
            BL      bus_on                      ; Commit changes
            BL      bus_off                     ; Reset state.
            POP     {LR, R9-R12}
            MOV     PC, LR

; ----------------------------------------------
; function lcd_line1: Move cursor of the LCD to the start of 1st line.
lcd_line1   PUSH    {LR, R9-R12}
            BL      lcd_idle                    ; Wait until idle.
            LDR     R9, port_b                  ; Read current control values
            LDRB    R11, [R9]                   
            AND     R11, R11, #:11111001        ; Change RS = 0, R/W = 0 (Write)
            STRB    R11, [R9]                   ; Write new control values
            LDR     R10, port_a                 ; Load address for PORT A
            MOV     R12, #:10000000             ; Load reset instruction to R12
            STRB    R12, [R10]                  ; Save instruction to port A
            BL      bus_on                      ; Commit changes
            BL      bus_off                     ; Reset state.
            POP     {LR, R9-R12}
            MOV     PC, LR

; ----------------------------------------------
; function lcd_line2: Move cursor of the LCD to the start of 2nd line.
lcd_line2   PUSH    {LR, R9-R12}
            BL      lcd_idle                    ; Wait until idle.
            LDR     R9, port_b                  ; Read current control values
            LDRB    R11, [R9]                   
            AND     R11, R11, #:11111001        ; Change RS = 0, R/W = 0 (Write)
            STRB    R11, [R9]                   ; Write new control values
            LDR     R10, port_a                 ; Load address for PORT A
            MOV     R12, #:11000000             ; Load reset instruction to R12
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
            BEQ     lcd_chglne
            CMP     R10, #&0A                   ; Newline
            ADREQ   LR, lcp_pc_end              ; Set end of this function to LR.
            BEQ     lcd_chglne
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
li_s1       LDR     R9, port_b                  ; Read current control values
            LDRB    R11, [R9]                   
            AND     R11, R11, #:11111101        ; Change RS  = 0
            ORR     R11, R11, #:00000100        ; Change R/W = 1 (Read)
            STRB    R11, [R9]                   ; Write new control values
li_s2       BL      bus_on                      ; Enable Bus
li_s3       LDR     R9, port_a                  ; Read status byte
            LDRB    R12, [R9]                   
li_s4       BL      bus_off                     ; Disable Bus
li_s5       AND     R12, R12, #:10000000        ; Get only bit 7 of status byte
            CMP     R12, #:10000000             ; Is bit 7 of status byte high?
            BEQ     li_s2                       ; Yes, check again
            POP     {LR, R9, R11, R12}
            MOV     PC, LR                      ; No, LCD is idle now. Return.

; ----------------------------------------------
; function lcd_write: write the character given by R10 to LCD.
lcd_write   PUSH    {LR, R8-R11}
            BL      lcd_idle                    ; Step 1-5, wait until idle.
lw_s6       LDR     R9, port_b                  ; Read current control values
            LDRB    R11, [R9]             
            ORR     R11, R11, #:00000010        ; Change RS  = 1
            AND     R11, R11, #:11111011        ; Change R/W = 0 (Write)
            STRB    R11, [R9]                   ; Write new control byte to Data.
lw_s7       LDR     R8, port_a                  ; Write data byte to data bus.
            STRB    R10, [R8]
lw_s8       BL      bus_on
lw_s9       BL      bus_off
            POP     {LR, R8-R11}
            MOV     PC, LR                      ; Return
; TODO: Change register protection code to the way like this one!

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
            AND     R11, R11, #:11111110        ; Set E to Low, preserve everything else.
            STRB    R11, [R9]                   ; Write new control values
            POP     {R9, R11}
            MOV     PC, LR                      ; Return

fin         B       fin                         ; Infinite loop. Halt.

; ----------------------------------------------
; Static memory pointer to the buses for LCD
port_a      DEFW    &1000_0000
port_b      DEFW    &1000_0004

; ----------------------------------------------
; Sample strings to print!
str1        DEFW    "Hello World!", 0
str2        DEFW    "Hachiroku.uk", 0           ; Actually, valid address!
str3        DEFW    "Higan\nEruthyll", 0

; ----------------------------------------------
; Stack Memory
stack       DEFS    128
stack_top   DEFW    0                           ; First unused location od stack