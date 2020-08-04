%include "./include/boot.inc"
SECTION secret vstart=SECRET_BASE_ADDR
ENC_FLAG:
    dd 0xec5574d8,0x421a04b5,0x2ba6d11,0x8105055f,0xeda06c28,0x6ae00499,0x18a955e7,0x71d63591,0x4537a864