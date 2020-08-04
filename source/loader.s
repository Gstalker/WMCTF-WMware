%include "./include/boot.inc"
SECTION LOADER vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
; usr_input equ es:0
USR_INPUT EQU 0x0

; enc_flag equ ds:0xfedcd4c8
ENC_FLAG EQU 0xfedcab33
; enc_usr_input_1(classical cryped) equ ds:0
ENC_STEP_ONE EQU 0x0
; enc_usr_input_2(xor by 129 times) equ ds:0x24
ENC_STEP_TWO EQU 0x24

jmp loader_start

;构建gdt及其内部的描述符
GDT_BASE:
    dd 0x00000000
    dd 0x00000000
CODE_DESC:;cs
    dd 0x0000ffff
    dd DESC_CODE_HIGH4
STACK_DESC:;ss
    dd 0x0000ffff
    dd DESC_STACK_HIGH4
VIDEO_DESC:;gs
    dd 0x8000_0007;limit = (0xbffff - b8000)/4k = 0x7
    dd DESC_VIDEO_HIGH4 ;此时DPL为0
USR_INPUT_DESC:;es 0x0000_8095
    dd 0x8095_0007
    dd DESC_USR_INPUT_HIGH4
DATA_DESC:;ds  0x0123_abcd
    dd 0xabcd_ffff
    dd DESC_MEM_HIGH4
GDT_SIZE equ $ - GDT_BASE
GDT_LIMIT equ GDT_SIZE - 1
times 60 dq 0 ;此处预留60个描述符空位

;选择子
SELECTOR_CODE equ (0x0001<<3) + TI_GDT + RPL0
SELECTOR_STACK equ (0x0002<<3) + TI_GDT + RPL0
SELECTOR_VIDEO equ (0x003<<3) + TI_GDT + RPL0
SELECTOR_USR_INPUT equ (0x004<<3) + TI_GDT + RPL0
SELECTOR_DATA equ (0x005<<3) + TI_GDT + RPL0


;以下是gdt的指针，前2字节是gdt界限，后4字节是gdt起始地址
gdt_ptr dw GDT_LIMIT
        dd GDT_BASE

loader_start:
    mov ax,0
    mov ds,ax
    mov bl,0xAE   ;打开键盘借口，允许发送数据
    call send_keyboard_op

    mov bl,0xf6   ;清空键盘缓冲区
    call send_keyboard_op

    call get_usr_input ;获取用户输入

    mov bl,0xf5   ;禁用键盘
    call send_keyboard_op

;_________准备进入保护模式___________
;1.打开A20Gate
;2.加载gdt
;3.将cr0的PE位置1
    ;-------------打开A20Gate-------------
    in al,0x92
    or al,0000_0010B
    out 0x92,al
    ;------------   加载GDT   ------------
    lgdt [gdt_ptr]
    ;------------cr0的PE位置为1------------
    mov eax,cr0
    or eax,0x0000_0001
    mov cr0,eax

    jmp dword SELECTOR_CODE:p_mode_start;刷新流水线

;进入保护模式
[bits 32]
p_mode_start:
    mov ax,SELECTOR_STACK
    mov es,ax
    mov ss,ax
    mov esp,LOADER_STACK_TOP
    mov ax,SELECTOR_VIDEO
    mov gs,ax
    mov ax,SELECTOR_DATA
    mov ds,ax
    mov ax,SELECTOR_USR_INPUT
    mov es,ax

    mov cl,2
classical_cipher:;古典密码组合：行列密码+凯撒
    mov esi,0  ;for(int i = 0 ;
  .loop_outside:
    cmp esi,6  ; i != 6 ;
    jz .done

    mov edi,0  ;for(int n = 0 ;   
  .loop_inside:
    cmp edi,6  ; n != 6 ;
    jz .next
   ;{
        mov ebx,esi ;ebx = esi*4 + esi*2
        shl ebx,cl
        shl esi,1
        add ebx,esi
        shr esi,1
        mov al,[es:USR_INPUT+ebx+edi]  ;顺序读取用户输入
        jz .lebel1
        jnz .lebel1
        db 'USELESS'
  .lebel1:
        add al,0x55
        jz .lebel2
        jnz .lebel2
        db 0xeb
  .lebel2:

        mov ebx,edi ;ebx = edi*4 + esi*2
        shl ebx,cl
        shl edi,1
        add ebx,edi
        shr edi,1
        mov [ds:ENC_STEP_ONE+ebx+esi],al  ;按列存入缓存区1
   ;}
    inc edi    ; ++n)
    jmp .loop_inside

  .next:
    inc esi    ; ++i)
    jmp .loop_outside

  .done:
    jmp dword SELECTOR_CODE:CHECKER_BASE_ADDR

[bits 16]
;   函数 get_usr_input
;   功能：读取用户输入，并存放到0x7e3:0x265这个位置(0x0000 8095)
;   位置的含义：写成十进制：2019:0613,我和她开始的日期。对于做题的人来说，当作一个无意义地址处理就成。
get_usr_input:
    push ax
    push bx
    push cx
    push si
    xor bx,bx
    mov si,0x265
  .reading:    ;读取一个键盘输入
    call get_keyboard_input
    cmp al,KEY_ENTER
    jz .done
    cmp al,KEY_BACKSPACE
    jnz .output
  ;退格建处理
    cmp bx,0    ;如果为0，说明还没输入东西，就不退格
    jz .reading
    push ds
    mov cx,0x7e3
    mov ds,cx
    mov ax,0x0820 ;清除已经输入的东西
    xor dl,dl
    sub bx,2
    dec si
    mov [gs:bx+160*3+0],ax
    mov [si],dl
    pop ds
    jmp .reading
  .output:    ;输出当前读到的字符
    push ds   
    mov cx,0x7e3
    mov ds,cx
    mov ah,0x06
    mov [gs:bx+160*3+0],ax
    mov [si],dl
    add bx,2  ;切换要输出的位置
    inc si    ;切换要输出的位置
    pop ds
    jmp .reading
  .done:    ;用户认为读完了，退出程序
    push ds   ;切换要输出的位置
    mov cx,0x7e3
    mov ds,cx
    mov dl,0
    mov [si],dl
    pop ds
    pop si
    pop cx
    pop bx
    pop ax
    ret


;   函数:get_keyboard_inout:
;   功能:读取一个键盘输入的字符
;   al = ascii码，dl = 通码
;   只支持字母，空格和数字
get_keyboard_input:
    push bx
  .try_get_input:
    in al,KEY_BOARD_COMMAND_PORT
    and al,01b
    jz .try_get_input           ;检测：是否允许读入
    in al,KEY_BOARD_INPUT_PORT
    cmp al,0x3a
    ja .try_get_input           ;检测：是否在读入范围内
    xor ah,ah
    mov bx,KEYBOARD_MAP
    add bx,ax
    mov dl,al
    mov al,[bx]
    cmp al,0x00                 ;取Ascii码，并检测是否是有效的ascii码
    jz  .try_get_input
    mov ah,[CAPS_LOCK]
    cmp al,KEY_CAPS_LOCK        ;大写🔓
    jnz .caps_check
    xor ah,01b
    mov [CAPS_LOCK],ah
    jmp .try_get_input
  .caps_check:              ;检测大写🔓，如果为1，则转换为大写ASCII码
    and ah,01b
    jz .finish
    cmp al,'a'
    jl .finish
    cmp al,'z'
    jg .finish
    add dl,0x30    ;通码加上0x30代表大写字符
    sub al,0x20    ;转换为大写字符
  .finish:
    pop bx
    ret
    

;   函数send_keyboard_op
;   功能:向键盘发送一个命令
;   bl = 命令号
send_keyboard_op:
    in al,KEY_BOARD_COMMAND_PORT
    and al,010b
    jnz send_keyboard_op
    mov al,bl
    out KEY_BOARD_COMMAND_PORT,al;
    ret

KEYBOARD_MAP:
    db KEY_UNDEFINED
    db KEY_UNDEFINED
    db '1'
    db '2'
    db '3'
    db '4'
    db '5'
    db '6'
    db '7'
    db '8'
    db '9'
    db '0'
    db '_'
    db '+'
    db KEY_BACKSPACE ;backspace
    db KEY_UNDEFINED
    db 'q'
    db 'w'
    db 'e'
    db 'r'
    db 't'
    db 'y'
    db 'u'
    db 'i'
    db 'o'
    db 'p'
    db '{'
    db '}'
    db KEY_ENTER ;enter
    db KEY_UNDEFINED
    db 'a'
    db 's'
    db 'd'
    db 'f'
    db 'g'
    db 'h'
    db 'j'
    db 'k'
    db 'l'
    db KEY_UNDEFINED
    db KEY_UNDEFINED
    db KEY_UNDEFINED
    db KEY_UNDEFINED
    db KEY_UNDEFINED
    db 'z'
    db 'x'
    db 'c'
    db 'v'
    db 'b'
    db 'n'
    db 'm'
    db KEY_UNDEFINED
    db KEY_UNDEFINED
    db KEY_UNDEFINED
    db KEY_UNDEFINED
    db KEY_UNDEFINED
    db KEY_UNDEFINED
    db ' '
    db KEY_CAPS_LOCK
CAPS_LOCK:
    db 0
