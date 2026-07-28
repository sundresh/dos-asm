00000000  48C7C075001000    mov rax,0x100075
00000007  48C7C275001000    mov rdx,0x100075
0000000E  4829C2            sub rdx,rax
00000011  48C7C775001000    mov rdi,0x100075
00000018  31F6              xor esi,esi
0000001A  FF2558000000      jmp qword near [rel 0x78]
00000020  E90B000000        jmp 0x30
00000025  CC                int3
00000026  CC                int3
00000027  CC                int3
00000028  CC                int3
00000029  CC                int3
0000002A  CC                int3
0000002B  CC                int3
0000002C  CC                int3
0000002D  CC                int3
0000002E  CC                int3
0000002F  CC                int3
00000030  4989D0            mov r8,rdx
00000033  4889FA            mov rdx,rdi
00000036  400FB6CE          movzx ecx,sil
0000003A  48B8010101010101  mov rax,0x101010101010101
         -0101
00000044  480FAFC1          imul rax,rcx
00000048  89D1              mov ecx,edx
0000004A  F7D9              neg ecx
0000004C  83E107            and ecx,0x7
0000004F  4939C8            cmp r8,rcx
00000052  490F42C8          cmovc rcx,r8
00000056  4929C8            sub r8,rcx
00000059  4C89C6            mov rsi,r8
0000005C  48C1EE03          shr rsi,byte 0x3
00000060  4183E007          and r8d,0x7
00000064  F3AA              rep stosb
00000066  4889F1            mov rcx,rsi
00000069  F348AB            rep stosq
0000006C  4C89C1            mov rcx,r8
0000006F  F3AA              rep stosb
00000071  4889D0            mov rax,rdx
00000074  C3                ret
00000075  0000              add [rax],al
00000077  0020              add [rax],ah
00000079  0010              add [rax],dl
0000007B  0000              add [rax],al
0000007D  0000              add [rax],al
0000007F  00                db 0x00
