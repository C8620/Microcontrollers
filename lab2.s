            ADR     SP, stack_top               ; Initialise the Stack
            BL      lcd_lights
            ADR     R0, str1
            ADR     R1, str1_end
loop        LDR     R10, [R0]
            BL      lcd_write
            ADD     R0, R0, #4
            CMP     R0, R1
            BNE     loop
            B       fin

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
str1        DEFW    &48, &65, &6C, &6C, &6F, &20, &57, &6F, &72, &6C, &64, &21
str1_end    DEFW    0

; ----------------------------------------------
; Stack Memory
stack       DEFS    256
stack_top   DEFW    0                           ; First unused location od stack