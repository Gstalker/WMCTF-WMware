enc_flag = [0xec5574d8,0x421a04b5,0x2ba6d11,0x8105055f,0xeda06c28,0x6ae00499,0x18a955e7,0x71d63591,0x4537a864]
for n in range(128,-1,-1):               #129轮逻辑运算
    for i in range(8,-1,-1):
        if (n%3 == 0):
            enc_flag[i] = enc_flag[i]^enc_flag[(i+1)%9]^0x24114514
        elif(n%3 == 1):
            enc_flag[i] = enc_flag[i]^enc_flag[(i+1)%9]^0x1919810
        elif(n%3 == 2):
            enc_flag[i] = enc_flag[i]^enc_flag[(i+1)%9]^0x19260817

group = [None] * (len(enc_flag) * 4)
for i in range(9):
    for n in range(4):
        group[i*4+n] = (enc_flag[i]>>(8*n))&0xff

for i in range(len(group)):#凯撒解密
    group[i] = (group[i] - 0x55)%0x100


flag = [None] * len(group)
for i in range(6):#行列密码解密
    for n in range(6):
        flag[i*6+n] = group[n*6+i]

key_board_mapping = {
    0x2:'1',
    0x3:'2',
    0x4:'3',
    0x5:'4',
    0x6:'5',
    0x7:'6',
    0x8:'7',
    0x9:'8',
    0xa:'9',
    0xb:'0',
    0xc:'_',
    0xd:'+',
    0x10:'q',
    0x11:'w',
    0x12:'e',
    0x13:'r',
    0x14:'t',
    0x15:'y',
    0x16:'u',
    0x17:'i',
    0x18:'o',
    0x19:'p',
    0x1a:'{',
    0x1b:'}',
    0x1e:'a',
    0x1f:'s',
    0x20:'d',
    0x21:'f',
    0x22:'g',
    0x23:'h',
    0x24:'j',
    0x25:'k',
    0x26:'l',
    0x2c:'z',
    0x2d:'x',
    0x2e:'c',
    0x2f:'v',
    0x30:'b',
    0x31:'n',
    0x32:'m',
    0x39:' ',
    }

for i in range(len(flag)):#键盘映射回去
    if flag[i]>0x39:
        flag[i] -= 0x30
        flag[i] = key_board_mapping[flag[i]].upper()
    else:
        flag[i] = key_board_mapping[flag[i]]

for i in flag:
    print(i,end = '')