%include "./include/boot.inc"
SECTION secret vstart=CHECKER_BASE_ADDR

; usr_input equ es:0
USR_INPUT EQU 0x0

; enc_flag equ ds:0xfedcd4c8
ENC_FLAG EQU 0xfedcab33
; enc_usr_input_1(classical cryped) equ ds:0
ENC_STEP_ONE EQU 0x0
; enc_usr_input_2(xor by 129 times) equ ds:0x24
ENC_STEP_TWO EQU 0x24

[bits 32]
    jmp checker_start
checker_start:
    xor ecx,ecx
xor_calc:
    cmp ecx,129
    jz check
    
    xor esi,esi
  .single_tern:
    cmp esi,9
    jz .next

    xor edx,edx
    mov eax,esi
    inc eax
    mov ebx,9
    div ebx
    mov edi,edx  ;edi = (esi+1) % 9,用于后面取值

    xor edx,edx
    mov eax,ecx
    mov ebx,3
    div ebx     ;edx = ecx % 3 用于进入分支处理

    jz .switch_table
    jnz .switch_table
    retn 0x99

  .switch_table:
    cmp edx,0   ;分支跳转,ecx % 3
    jz .xor0
    cmp edx,1
    jz .xor1
    jnz .xor2

  ;enc_step_one[i] = enc_step_one[i]^enc_step_one[(i+1)%9]^0x24114514
  .xor0:;空闲寄存器：eax,ebx,edx,edi
    shl esi,2
    mov eax,[ds:ENC_STEP_ONE+esi] ;i
    shl edi,2
    mov ebx,[ds:ENC_STEP_ONE+edi] ;i+1
    mov edx,eax
    mov edi,ebx

    or eax,ebx
    not edx
    not edi
    or edx,edi
    and eax,edx
    
    mov edx,eax
    mov ebx,0x24114514
    mov edi,ebx

    not eax
    not ebx
    and eax,ebx
    not eax
    and edx,edi
    not edx
    and eax,edx

    mov [ds:ENC_STEP_ONE+esi],eax
    jmp .xor_next
  ;enc_step_one[i] = enc_step_one[i]^enc_step_one[(i+1)%9]^0x1919810
  .xor1:
    shl esi,2
    mov eax,[ds:ENC_STEP_ONE+esi] ;i
    shl edi,2
    mov ebx,[ds:ENC_STEP_ONE+edi] ;i+1
    mov edx,eax
    mov edi,ebx

    not eax
    not ebx
    and eax,ebx
    not eax
    and edx,edi
    not edx
    and eax,edx
    
    mov edx,eax
    mov ebx,0x1919810
    mov edi,ebx

    not ebx
    and eax,ebx
    not edx
    and edx,edi
    or eax,edx
    mov [ds:ENC_STEP_ONE+esi],eax
    jmp .xor_next

  ;enc_step_one[i] = enc_step_one[i]^enc_step_one[(i+1)%9]^0x19260817
  .xor2:
    shl esi,2
    mov eax,[ds:ENC_STEP_ONE+esi] ;i
    shl edi,2
    mov ebx,[ds:ENC_STEP_ONE+edi] ;i+1
    mov edx,eax
    mov edi,ebx

    not ebx
    and eax,ebx
    not edx
    and edx,edi
    or eax,edx

    mov edx,eax
    mov ebx,0x19260817
    mov edi,ebx

    or eax,ebx
    not edx
    not edi
    or edx,edi
    and eax,edx
    
    mov [ds:ENC_STEP_ONE+esi],eax
  .xor_next:
    shr esi,2
    inc esi
    jmp .single_tern
  .next:  
    inc ecx
    jmp xor_calc
check:
    xor ecx,ecx
    xor edx,edx
  .looping:
    cmp ecx,18
    jz judge
    shl ecx,1
    mov ax,[ds:ENC_FLAG+ecx]
    mov bx,[ds:ENC_STEP_ONE+ecx]
    cmp ax,bx
    jz .next
    inc edx
  .next:
    shr ecx,1
    inc ecx
    jmp .looping
judge:
    cmp edx,0
    jnz .error
    mov byte [gs:160*5+0],'A'
    mov byte [gs:160*5+1],0x02
    mov byte [gs:160*5+2],'c'
    mov byte [gs:160*5+3],0x02
    mov byte [gs:160*5+4],'c'
    mov byte [gs:160*5+5],0x02
    mov byte [gs:160*5+6],'e'
    mov byte [gs:160*5+7],0x02
    mov byte [gs:160*5+8],'s'
    mov byte [gs:160*5+9],0x02
    mov byte [gs:160*5+10],'s'
    mov byte [gs:160*5+11],0x02
    jmp waiting
  .error:
    mov byte [gs:160*5+0],'F'
    mov byte [gs:160*5+1],0x04
    mov byte [gs:160*5+2],'a'
    mov byte [gs:160*5+3],0x04
    mov byte [gs:160*5+4],'i'
    mov byte [gs:160*5+5],0x04
    mov byte [gs:160*5+6],'l'
    mov byte [gs:160*5+7],0x04
waiting:
    jmp $