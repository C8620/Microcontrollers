        MOV  R0, #&1000_0000
loop    MOV  R1, #&44       ; Red, Red
        STRB R1, [R0]
        MOV  R10, #1
        BL   time
        MOV  R1, #&46       ; Red+Amber, Red
        STRB R1, [R0]
        MOV  R10, #1
        BL   time
        MOV  R1, #&41       ; Green, Red
        STRB R1, [R0]
        MOV  R10, #3
        BL   time
        MOV  R1, #&42       ; Amber, Red
        STRB R1, [R0]
        MOV  R10, #1
        BL   time

        MOV  R1, #&44       ; Red, Red
        STRB R1, [R0]
        MOV  R10, #1
        BL   time
        MOV  R1, #&64       ; Red, Red+Amber
        STRB R1, [R0]
        MOV  R10, #1
        BL   time
        MOV  R1, #&14       ; Red, Green
        STRB R1, [R0]
        MOV  R10, #3
        BL   time
        MOV  R1, #&24       ; Red, Amber
        STRB R1, [R0]
        MOV  R10, #1
        BL   time
        B    loop

; subroutine time - spend given seconds in R10.
time    CMP  R10, #0
        BEQ  timefi         ; complete, return.
        SUB  R10, R10, #1
        MOV  R11, #&40000   ; spend 1 second
timelp  SUB  R11, R11, #1        
        CMP  R11, #0
        BNE  timelp
        B    time
timefi  MOV  PC, LR