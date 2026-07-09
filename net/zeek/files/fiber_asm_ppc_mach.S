; PowerPC 32-bit context switch for Apple Darwin (powerpc-apple-darwin).
; ABI: 32-bit PowerPC Darwin / AIX-style ABI (big-endian).
; No TOC pointer, no .localentry, no @function type; external symbols are
; prefixed with an underscore. General purpose registers are 32-bit
; (stw/lwz), floating point registers are 64-bit doubles (stfd/lfd),
; and AltiVec vector registers are 128-bit (stvx/lvx). Only G4/G5 (AltiVec
; capable) hardware is supported, so the vector state is saved
; unconditionally.
; Unlike the SysV/ELF PowerPC ABI, r13 is NOT a reserved thread pointer
; on Darwin - it is an ordinary callee-saved GPR - so r13-r31 are all saved.
; r2 is likewise environment/reserved and is preserved across the callee
; calls in invoke / exec_on_stack.
; The Darwin 32-bit linkage area is 24 bytes:
; 0(sp):  back chain
; 4(sp):  saved CR
; 8(sp):  saved LR
; 12(sp): reserved (compiler)
; 16(sp): reserved (binder)
; 20(sp): saved TOC (r2)

  .machine ppc7400
  .text
  .align 2

#define FUNC(sym) \
  .globl _##sym; \
  .align 4; \
  _##sym:

#define END_FUNC(sym)

  .macro check_stack_alignment
  .endm

FUNC(fiber_asm_switch)

  ; CR
  mfcr r5
  stw r5, 0(r3)
  lwz r5, 0(r4)
  mtcr r5

  ; VRSAVE
  mfspr r6, 256
  stw r6, 4(r3)
  lwz r6, 4(r4)
  mtspr 256, r6

  ; LR
  mflr r0
  stw r0, 8(r3)
  lwz r0, 8(r4)
  mtlr r0

  ; SP
  stw r1,  12(r3)
  lwz r1,  12(r4)

  ; r13-r31 (19 GPRs) at offset 16
  stw r13, 16(r3)
  stw r14, 20(r3)
  stw r15, 24(r3)
  stw r16, 28(r3)
  stw r17, 32(r3)
  stw r18, 36(r3)
  stw r19, 40(r3)
  stw r20, 44(r3)
  stw r21, 48(r3)
  stw r22, 52(r3)
  stw r23, 56(r3)
  stw r24, 60(r3)
  stw r25, 64(r3)
  stw r26, 68(r3)
  stw r27, 72(r3)
  stw r28, 76(r3)
  stw r29, 80(r3)
  stw r30, 84(r3)
  stw r31, 88(r3)

  lwz r13, 16(r4)
  lwz r14, 20(r4)
  lwz r15, 24(r4)
  lwz r16, 28(r4)
  lwz r17, 32(r4)
  lwz r18, 36(r4)
  lwz r19, 40(r4)
  lwz r20, 44(r4)
  lwz r21, 48(r4)
  lwz r22, 52(r4)
  lwz r23, 56(r4)
  lwz r24, 60(r4)
  lwz r25, 64(r4)
  lwz r26, 68(r4)
  lwz r27, 72(r4)
  lwz r28, 76(r4)
  lwz r29, 80(r4)
  lwz r30, 84(r4)
  lwz r31, 88(r4)

  ; f14-f31 (18 FPRs) at offset 96
  ; (offset 92 is __pad, never written - compiler inserts it for alignment)
  stfd f14,  96(r3)
  stfd f15, 104(r3)
  stfd f16, 112(r3)
  stfd f17, 120(r3)
  stfd f18, 128(r3)
  stfd f19, 136(r3)
  stfd f20, 144(r3)
  stfd f21, 152(r3)
  stfd f22, 160(r3)
  stfd f23, 168(r3)
  stfd f24, 176(r3)
  stfd f25, 184(r3)
  stfd f26, 192(r3)
  stfd f27, 200(r3)
  stfd f28, 208(r3)
  stfd f29, 216(r3)
  stfd f30, 224(r3)
  stfd f31, 232(r3)

  lfd f14,  96(r4)
  lfd f15, 104(r4)
  lfd f16, 112(r4)
  lfd f17, 120(r4)
  lfd f18, 128(r4)
  lfd f19, 136(r4)
  lfd f20, 144(r4)
  lfd f21, 152(r4)
  lfd f22, 160(r4)
  lfd f23, 168(r4)
  lfd f24, 176(r4)
  lfd f25, 184(r4)
  lfd f26, 192(r4)
  lfd f27, 200(r4)
  lfd f28, 208(r4)
  lfd f29, 216(r4)
  lfd f30, 224(r4)
  lfd f31, 232(r4)

  ; v20-v31 (12 VMX regs).
  ; 16-byte align the vN area in r3/r4.
  ; Fixed part ends at 96 + 18*8 = 240 bytes; round the running pointer up.
  addi r3, r3, 255
  rlwinm r3, r3, 0, 0, 27
  addi r4, r4, 255
  rlwinm r4, r4, 0, 0, 27

  stvx v20, 0, r3
  lvx  v20, 0, r4
  li r5, 16
  stvx v21, r3, r5
  lvx  v21, r4, r5
  li r5, 32
  stvx v22, r3, r5
  lvx  v22, r4, r5
  li r5, 48
  stvx v23, r3, r5
  lvx  v23, r4, r5
  li r5, 64
  stvx v24, r3, r5
  lvx  v24, r4, r5
  li r5, 80
  stvx v25, r3, r5
  lvx  v25, r4, r5
  li r5, 96
  stvx v26, r3, r5
  lvx  v26, r4, r5
  li r5, 112
  stvx v27, r3, r5
  lvx  v27, r4, r5
  li r5, 128
  stvx v28, r3, r5
  lvx  v28, r4, r5
  li r5, 144
  stvx v29, r3, r5
  lvx  v29, r4, r5
  li r5, 160
  stvx v30, r3, r5
  lvx  v30, r4, r5
  li r5, 176
  stvx v31, r3, r5
  lvx  v31, r4, r5

  blr

END_FUNC(fiber_asm_switch)

; On entry the fiber stack (built by fiber_reserve_return) holds,
; from the current sp upward:
; 0(sp):  pointer to args
; 4(sp):  function to call
; 8(sp):  old sp
; 12(sp): old lr
FUNC(fiber_asm_invoke)
  lwz r3,  0(r1)          ; args    -> r3 (first argument)
  lwz r12, 4(r1)          ; func    -> r12/ctr
  mtctr r12
  stwu r1, -24(r1)        ; 24-byte Darwin linkage frame
  stw r2, 20(r1)          ; preserve r2 across the call
  bctrl
  lwz r2, 20(r1)
  lwz r0, 36(r1)          ; old lr  (12 + 24)
  mtlr r0
  lwz r3, 32(r1)          ; old sp  (8 + 24)
  mr r1, r3
  blr
END_FUNC(fiber_asm_invoke)

; void fiber_asm_exec_on_stack(void *arg, FiberFunc f, void *stack)
; r3 = arg, r4 = f, r5 = new stack
FUNC(fiber_asm_exec_on_stack)
  mflr r0
  mr r6, r31              ; save caller's r31
  mr r12, r4              ; f -> ctr
  mtctr r4
  mr r31, r1              ; remember caller sp in r31
  stw r0, 8(r1)           ; save lr in caller frame linkage
  mr r1, r5               ; switch to the temp stack
  stw r6, -8(r1)          ; stash caller's r31 below new sp
  stwu r1, -24(r1)        ; 24-byte Darwin linkage frame
  stw r2, 20(r1)          ; preserve r2 across the call (linkage TOC slot)
  bctrl
  lwz r2, 20(r1)
  mr r3, r31              ; restore caller sp
  lwz r31, 16(r1)         ; reload saved r31 (24 - 8)
  mr r1, r3
  lwz r0, 8(r1)
  mtlr r0
  blr
END_FUNC(fiber_asm_exec_on_stack)

#ifdef FIBER_ASM_CHECK_ALIGNMENT
_align_check_failed:
  b _fiber_align_check_failed
#endif
