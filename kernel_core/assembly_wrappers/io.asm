global out_wrapper

out_wrapper:
    ; C Signature:
    ; out_wrapper(unsigned short port, unsigned char data)
    mov al, [esp + 8]
    mov dx, [esp + 4]
    out dx, al
    ret
