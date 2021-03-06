/*********************************************************************/
/*                                                                   */
/*             Optimized BLAS libraries                              */
/*                     By Kazushige Goto <kgoto@tacc.utexas.edu>     */
/*                                                                   */
/* Copyright (c) The University of Texas, 2009. All rights reserved. */
/* UNIVERSITY EXPRESSLY DISCLAIMS ANY AND ALL WARRANTIES CONCERNING  */
/* THIS SOFTWARE AND DOCUMENTATION, INCLUDING ANY WARRANTIES OF      */
/* MERCHANTABILITY, FITNESS FOR ANY PARTICULAR PURPOSE,              */
/* NON-INFRINGEMENT AND WARRANTIES OF PERFORMANCE, AND ANY WARRANTY  */
/* THAT MIGHT OTHERWISE ARISE FROM COURSE OF DEALING OR USAGE OF     */
/* TRADE. NO WARRANTY IS EITHER EXPRESS OR IMPLIED WITH RESPECT TO   */
/* THE USE OF THE SOFTWARE OR DOCUMENTATION.                         */
/* Under no circumstances shall University be liable for incidental, */
/* special, indirect, direct or consequential damages or loss of     */
/* profits, interruption of business, or related expenses which may  */
/* arise from use of Software or Documentation, including but not    */
/* limited to those resulting from defects in Software and/or        */
/* Documentation, or loss or inaccuracy of data of any kind.         */
/*********************************************************************/

#define ASSEMBLER
#include "common.h"
		
#ifndef __64BIT__
#define LOAD	lwz
#else
#define LOAD	ld
#endif

#ifdef __64BIT__
#define STACKSIZE 320
#define ALPHA_R 296(SP)
#define ALPHA_I 304(SP)
#define FZERO	312(SP)
#else
#define STACKSIZE 256
#define ALPHA_R 224(SP)
#define ALPHA_I 232(SP)
#define FZERO	240(SP)
#endif

#define	M	r3
#define	N	r4
#define	K	r5

#ifdef linux
#ifndef __64BIT__
#define A	r6
#define	B	r7
#define	C	r8
#define	LDC	r9
#define OFFSET	r10
#else
#define A	r8
#define	B	r9
#define	C	r10
#define	LDC	r6
#define OFFSET	r7
#endif
#endif

#if defined(_AIX) || defined(__APPLE__)
#if !defined(__64BIT__) && defined(DOUBLE)
#define A	r10
#define	B	r6
#define	C	r7
#define	LDC	r8
#define OFFSET	r9
#else
#define A	r8
#define	B	r9
#define	C	r10
#define	LDC	r6
#define OFFSET	r7
#endif
#endif

#define AORIG	r21
#define TEMP	r22
#define KK	r23
#define	I	r24
#define J	r25
#define AO	r26
#define	BO	r27
#define	CO1	r28
#define CO2	r29

#define A1	f16
#define A2	f17
#define A3	f18
#define A4	f19
#define A5	f20
#define A6	f21
#define B1	f22
#define B2	f23
#define B3	f24
#define B4	f25
#define B5	f26
#define B6	f27
#define B7	f28
#define B8	f29
#define B9	f30
#define B10	f31

	PROLOGUE
	PROFCODE

	addi	SP, SP, -STACKSIZE
	li	r0, 0

	stfd	f14,    0(SP)
	stfd	f15,    8(SP)
	stfd	f16,   16(SP)
	stfd	f17,   24(SP)

	stfd	f18,   32(SP)
	stfd	f19,   40(SP)
	stfd	f20,   48(SP)
	stfd	f21,   56(SP)

	stfd	f22,   64(SP)
	stfd	f23,   72(SP)
	stfd	f24,   80(SP)
	stfd	f25,   88(SP)

	stfd	f26,   96(SP)
	stfd	f27,  104(SP)
	stfd	f28,  112(SP)
	stfd	f29,  120(SP)

	stfd	f30,  128(SP)
	stfd	f31,  136(SP)

#ifdef __64BIT__
	std	r31,  144(SP)
	std	r30,  152(SP)
	std	r29,  160(SP)
	std	r28,  168(SP)
	std	r27,  176(SP)
	std	r26,  184(SP)
	std	r25,  192(SP)
	std	r24,  200(SP)
	std	r23,  208(SP)
	std	r22,  216(SP)
	std	r21,  224(SP)
#else
	stw	r31,  144(SP)
	stw	r30,  148(SP)
	stw	r29,  152(SP)
	stw	r28,  156(SP)
	stw	r27,  160(SP)
	stw	r26,  164(SP)
	stw	r25,  168(SP)
	stw	r24,  172(SP)
	stw	r23,  176(SP)
	stw	r22,  180(SP)
	stw	r21,  184(SP)
#endif

	stw	r0,  FZERO

#ifdef linux
#ifdef __64BIT__
	ld	LDC,    112 + STACKSIZE(SP)
#endif
#endif

#if defined(_AIX) || defined(__APPLE__)
#ifdef __64BIT__
	ld	LDC,    112 + STACKSIZE(SP)
#else
#ifdef DOUBLE
	lwz	B,       56 + STACKSIZE(SP)
	lwz	C,       60 + STACKSIZE(SP)
	lwz	LDC,     64 + STACKSIZE(SP)
#else
	lwz	LDC,     56 + STACKSIZE(SP)
#endif
#endif
#endif

#if defined(linux) && defined(__64BIT__)
	ld	OFFSET,  120 + STACKSIZE(SP)
#endif

#if defined(_AIX) || defined(__APPLE__)
#ifdef __64BIT__
	ld	OFFSET,  120 + STACKSIZE(SP)
#else
#ifdef DOUBLE
	lwz	OFFSET,   68 + STACKSIZE(SP)
#else
	lwz	OFFSET,   60 + STACKSIZE(SP)
#endif
#endif
#endif

	slwi	LDC, LDC, ZBASE_SHIFT

#ifdef LN
	mullw	r0, M, K
	slwi	r0, r0, ZBASE_SHIFT
	add	A, A, r0

	slwi	r0, M, ZBASE_SHIFT
	add	C, C, r0
#endif

#ifdef RN
	neg	KK, OFFSET
#endif

#ifdef RT
	mullw	r0, N, K
	slwi	r0, r0, ZBASE_SHIFT
	add	B, B, r0

	mullw	r0, N, LDC
	add	C, C, r0

	sub	KK, N, OFFSET
#endif

	cmpwi	cr0, M, 0
	ble	.L999
	cmpwi	cr0, N, 0
	ble	.L999
	cmpwi	cr0, K, 0
	ble	.L999

	andi.	J, N,  1
	ble	.L30

#ifdef RT
	slwi	r0, K, 0 + ZBASE_SHIFT
	sub	B, B, r0

	sub	C, C, LDC
#endif

	mr	CO1, C

#ifdef LN
	add	KK, M, OFFSET
#endif

#ifdef LT
	mr	KK, OFFSET
#endif

	srawi.	I,  M,  1
#if defined(LN) || defined(RT)
	mr	AORIG, A
#else
	mr	AO, A
#endif
#ifndef RT
	add	C, C, LDC
#endif
	ble	.L40
	.align 4

.L31:
#if defined(LT) || defined(RN)
	LFD	f20,  0 * SIZE(AO)
	LFD	f21,  1 * SIZE(AO)
	LFD	f22,  2 * SIZE(AO)
	LFD	f23,  3 * SIZE(AO)

	LFD	f24,  4 * SIZE(AO)
	LFD	f25,  5 * SIZE(AO)
	LFD	f26,  6 * SIZE(AO)
	LFD	f27,  7 * SIZE(AO)

	LFD	f16, 0 * SIZE(B)
	LFD	f17, 1 * SIZE(B)
	LFD	f18, 2 * SIZE(B)
	LFD	f19, 3 * SIZE(B)

	lfs	f0, FZERO
	fmr	f1, f0
	fmr	f2, f0
	fmr	f3, f0
	fmr	f4, f0
	fmr	f5, f0
	fmr	f6, f0
	fmr	f7, f0

	srawi.	r0, KK,  2
	mr	BO,  B
	mtspr	CTR, r0
#else

#ifdef LN
	slwi	r0,   K,  1 + ZBASE_SHIFT
	sub	AORIG, AORIG, r0
#endif

	slwi	r0,   KK, 1 + ZBASE_SHIFT
	slwi	TEMP, KK, 0 + ZBASE_SHIFT

	add	AO, AORIG, r0
	add	BO, B,     TEMP

	sub	TEMP, K, KK

	LFD	f20,  0 * SIZE(AO)
	LFD	f21,  1 * SIZE(AO)
	LFD	f22,  2 * SIZE(AO)
	LFD	f23,  3 * SIZE(AO)

	LFD	f24,  4 * SIZE(AO)
	LFD	f25,  5 * SIZE(AO)
	LFD	f26,  6 * SIZE(AO)
	LFD	f27,  7 * SIZE(AO)

	LFD	f16, 0 * SIZE(BO)
	LFD	f17, 1 * SIZE(BO)
	LFD	f18, 2 * SIZE(BO)
	LFD	f19, 3 * SIZE(BO)

	lfs	f0, FZERO
	fmr	f1, f0
	fmr	f2, f0
	fmr	f3, f0
	fmr	f4, f0
	fmr	f5, f0
	fmr	f6, f0
	fmr	f7, f0

	srawi.	r0, TEMP,  2
	mtspr	CTR, r0
#endif
	ble	.L35
	.align 4

.L32:
	fmadd	f0,  f16, f20, f0
	LFD	f19,  3 * SIZE(BO)
	fmadd	f1,  f16, f21, f1
	nop
	fmadd	f2,  f16, f22, f2
	nop
	fmadd	f3,  f16, f23, f3
	LFD	f16,  4 * SIZE(BO)

	fmadd	f4,  f17, f20, f4
	LFD	f20,  8 * SIZE(AO)
	fmadd	f5,  f17, f21, f5
	LFD	f21,  9 * SIZE(AO)
	fmadd	f6,  f17, f22, f6
	LFD	f22, 10 * SIZE(AO)
	fmadd	f7,  f17, f23, f7
	LFD	f23, 11 * SIZE(AO)

	fmadd	f0,  f18, f24, f0
	LFD	f17,  5 * SIZE(BO)
	fmadd	f1,  f18, f25, f1
	nop
	fmadd	f2,  f18, f26, f2
	nop
	fmadd	f3,  f18, f27, f3
	LFD	f18,  6 * SIZE(BO)

	fmadd	f4,  f19, f24, f4
	LFD	f24, 12 * SIZE(AO)
	fmadd	f5,  f19, f25, f5
	LFD	f25, 13 * SIZE(AO)
	fmadd	f6,  f19, f26, f6
	LFD	f26, 14 * SIZE(AO)
	fmadd	f7,  f19, f27, f7
	LFD	f27, 15 * SIZE(AO)

	fmadd	f0,  f16, f20, f0
	LFD	f19,  7 * SIZE(BO)
	fmadd	f1,  f16, f21, f1
	nop
	fmadd	f2,  f16, f22, f2
	nop
	fmadd	f3,  f16, f23, f3
	LFDU	f16,  8 * SIZE(BO)

	fmadd	f4,  f17, f20, f4
	LFDU	f20, 16 * SIZE(AO)
	fmadd	f5,  f17, f21, f5
	LFD	f21,  1 * SIZE(AO)
	fmadd	f6,  f17, f22, f6
	LFD	f22,  2 * SIZE(AO)
	fmadd	f7,  f17, f23, f7
	LFD	f23,  3 * SIZE(AO)

	fmadd	f0,  f18, f24, f0
	LFD	f17,  1 * SIZE(BO)
	fmadd	f1,  f18, f25, f1
	nop
	fmadd	f2,  f18, f26, f2
	nop
	fmadd	f3,  f18, f27, f3
	LFD	f18,  2 * SIZE(BO)

	fmadd	f4,  f19, f24, f4
	LFD	f24,  4 * SIZE(AO)
	fmadd	f5,  f19, f25, f5
	LFD	f25,  5 * SIZE(AO)
	fmadd	f6,  f19, f26, f6
	LFD	f26,  6 * SIZE(AO)
	fmadd	f7,  f19, f27, f7
	LFD	f27,  7 * SIZE(AO)
	bdnz	.L32
	.align 4

.L35:
#if defined(LT) || defined(RN)
	andi.	r0, KK,  3
#else
	andi.	r0, TEMP, 3
#endif
	mtspr	CTR, r0
	ble	.L37
	.align 4

.L36:
	fmadd	f0,  f16, f20, f0
	LFD	f17, 1 * SIZE(BO)
	fmadd	f1,  f16, f21, f1
	nop
	fmadd	f2,  f16, f22, f2
	nop
	fmadd	f3,  f16, f23, f3
	LFDU	f16, 2 * SIZE(BO)

	fmadd	f4,  f17, f20, f4
	LFDU	f20, 4 * SIZE(AO)
	fmadd	f5,  f17, f21, f5
	LFD	f21, 1 * SIZE(AO)
	fmadd	f6,  f17, f22, f6
	LFD	f22, 2 * SIZE(AO)
	fmadd	f7,  f17, f23, f7
	LFD	f23, 3 * SIZE(AO)
	bdnz	.L36
	.align 4

.L37:
#ifndef CONJ
	FSUB	  f0,  f0,  f5
	FADD	  f1,  f1,  f4
	FSUB	  f2,  f2,  f7
	FADD	  f3,  f3,  f6
#else
	FADD	  f0,  f0,  f5
	FSUB	  f1,  f4,  f1
	FADD	  f2,  f2,  f7
	FSUB	  f3,  f6,  f3
#endif

#if defined(LN) || defined(RT)
#ifdef LN
	subi	r0, KK, 2
#else
	subi	r0, KK, 1
#endif
	slwi	TEMP, r0, 1 + ZBASE_SHIFT
	slwi	r0,   r0, 0 + ZBASE_SHIFT

	add	AO, AORIG, TEMP
	add	BO, B,     r0
#endif

#if defined(LN) || defined(LT)
	LFD	f16,  0 * SIZE(BO)
	LFD	f17,  1 * SIZE(BO)
	LFD	f18,  2 * SIZE(BO)
	LFD	f19,  3 * SIZE(BO)

	FSUB	f0,  f16, f0
	FSUB	f1,  f17, f1
	FSUB	f2,  f18, f2
	FSUB	f3,  f19, f3
#else
	LFD	f16,  0 * SIZE(AO)
	LFD	f17,  1 * SIZE(AO)
	LFD	f18,  2 * SIZE(AO)
	LFD	f19,  3 * SIZE(AO)

#ifndef CONJ
	FSUB	f0,  f16, f0
	FSUB	f1,  f17, f1
	FSUB	f2,  f18, f2
	FSUB	f3,  f19, f3
#else
	FSUB	f0,  f16, f0
	FADD	f1,  f17, f1
	FSUB	f2,  f18, f2
	FADD	f3,  f19, f3
#endif
#endif

#ifdef LN
	LFD	f16,  6 * SIZE(AO)
	LFD	f17,  7 * SIZE(AO)
	LFD	f18,  4 * SIZE(AO)
	LFD	f19,  5 * SIZE(AO)
	LFD	f20,  0 * SIZE(AO)
	LFD	f21,  1 * SIZE(AO)

	FMUL	f6,  f17, f3
	FMUL	f7,  f17, f2

#ifndef CONJ
	FMSUB	f2,  f16, f2,  f6
	FMADD	f3,  f16, f3,  f7

	FMADD	f0,  f19, f3,  f0
	FNMSUB	f1,  f19, f2,  f1
	FNMSUB	f0,  f18, f2,  f0
	FNMSUB	f1,  f18, f3,  f1

	FMUL	f4,  f21, f1
	FMUL	f5,  f21, f0
	FMSUB	f0,  f20, f0,  f4
	FMADD	f1,  f20, f1,  f5
#else
	FMADD	f2,  f16, f2,  f6
	FMSUB	f3,  f16, f3,  f7

	FMSUB	f0,  f19, f3,  f0
	FNMADD	f1,  f19, f2,  f1
	FNMADD	f0,  f18, f2,  f0
	FNMADD	f1,  f18, f3,  f1

	FMUL	f4,  f21, f1
	FMUL	f5,  f21, f0
	FMADD	f0,  f20, f0,  f4
	FMSUB	f1,  f20, f1,  f5
#endif
#endif

#ifdef LT
	LFD	f16,  0 * SIZE(AO)
	LFD	f17,  1 * SIZE(AO)
	LFD	f18,  2 * SIZE(AO)
	LFD	f19,  3 * SIZE(AO)
	LFD	f20,  6 * SIZE(AO)
	LFD	f21,  7 * SIZE(AO)

	FMUL	f4,  f17, f1
	FMUL	f5,  f17, f0

#ifndef CONJ
	FMSUB	f0,  f16, f0,  f4
	FMADD	f1,  f16, f1,  f5

	FMADD	f2,  f19, f1, f2
	FNMSUB	f3,  f19, f0, f3
	FNMSUB	f2,  f18, f0,  f2
	FNMSUB	f3,  f18, f1,  f3

	FMUL	f4,  f21, f3
	FMUL	f5,  f21, f2
	FMSUB	f2,  f20, f2,  f4
	FMADD	f3,  f20, f3,  f5
#else
	FMADD	f0,  f16, f0,  f4
	FMSUB	f1,  f16, f1,  f5

	FMSUB	f2,  f19, f1, f2
	FNMADD	f3,  f19, f0, f3
	FNMADD	f2,  f18, f0,  f2
	FNMADD	f3,  f18, f1,  f3

	FMUL	f4,  f21, f3
	FMUL	f5,  f21, f2
	FMADD	f2,  f20, f2,  f4
	FMSUB	f3,  f20, f3,  f5
#endif
#endif

#ifdef RN
	LFD	f16,  0 * SIZE(BO)
	LFD	f17,  1 * SIZE(BO)

	FMUL	f4,  f17, f1
	FMUL	f5,  f17, f0
	FMUL	f6,  f17, f3
	FMUL	f7,  f17, f2

#ifndef CONJ
	FMSUB	f0,  f16, f0,  f4
	FMADD	f1,  f16, f1,  f5
	FMSUB	f2,  f16, f2,  f6
	FMADD	f3,  f16, f3,  f7
#else
	FMADD	f0,  f16, f0,  f4
	FMSUB	f1,  f16, f1,  f5
	FMADD	f2,  f16, f2,  f6
	FMSUB	f3,  f16, f3,  f7
#endif
#endif

#ifdef RT
	LFD	f20,  0 * SIZE(BO)
	LFD	f21,  1 * SIZE(BO)

	FMUL	f4,  f21, f1
	FMUL	f5,  f21, f0
	FMUL	f6,  f21, f3
	FMUL	f7,  f21, f2

#ifndef CONJ
	FMSUB	f0,  f20, f0,  f4
	FMADD	f1,  f20, f1,  f5
	FMSUB	f2,  f20, f2,  f6
	FMADD	f3,  f20, f3,  f7

#else
	FMADD	f0,  f20, f0,  f4
	FMSUB	f1,  f20, f1,  f5
	FMADD	f2,  f20, f2,  f6
	FMSUB	f3,  f20, f3,  f7
#endif
#endif

#ifdef LN
	subi	CO1, CO1, 4 * SIZE
#endif

#if defined(LN) || defined(LT)
	STFD	f0,   0 * SIZE(BO)
	STFD	f1,   1 * SIZE(BO)
	STFD	f2,   2 * SIZE(BO)
	STFD	f3,   3 * SIZE(BO)
#else
	STFD	f0,   0 * SIZE(AO)
	STFD	f1,   1 * SIZE(AO)
	STFD	f2,   2 * SIZE(AO)
	STFD	f3,   3 * SIZE(AO)
#endif

	STFD	f0,   0 * SIZE(CO1)
	STFD	f1,   1 * SIZE(CO1)
	STFD	f2,   2 * SIZE(CO1)
	STFD	f3,   3 * SIZE(CO1)

#ifndef LN
	addi	CO1, CO1, 4 * SIZE
#endif

#ifdef RT
	slwi	r0, K, 1 + ZBASE_SHIFT
	add	AORIG, AORIG, r0
#endif

#if defined(LT) || defined(RN)
	sub	TEMP, K, KK
	slwi	r0,   TEMP, 1 + ZBASE_SHIFT
	slwi	TEMP, TEMP, 0 + ZBASE_SHIFT
	add	AO, AO, r0
	add	BO, BO, TEMP
#endif

#ifdef LT
	addi	KK, KK, 2
#endif

#ifdef LN
	subi	KK, KK, 2
#endif

	addic.	I, I, -1
	bgt	.L31
	.align 4

.L40:
	andi.	I,  M,  1
	ble	.L49

#if defined(LT) || defined(RN)
	LFD	f16,  0 * SIZE(AO)
	LFD	f17,  1 * SIZE(AO)
	LFD	f18,  2 * SIZE(AO)
	LFD	f19,  3 * SIZE(AO)

	LFD	f20,  0 * SIZE(B)
	LFD	f21,  1 * SIZE(B)
	LFD	f22,  2 * SIZE(B)
	LFD	f23,  3 * SIZE(B)

	lfs	f0, FZERO
	fmr	f1, f0
	fmr	f2, f0
	fmr	f3, f0
	fmr	f4, f0
	fmr	f5, f0
	fmr	f6, f0
	fmr	f7, f0

	srawi.	r0, KK,  2
	mr	BO,  B
	mtspr	CTR, r0
#else

#ifdef LN
	slwi	r0,   K,  0 + ZBASE_SHIFT
	sub	AORIG, AORIG, r0
#endif

	slwi	r0,   KK, 0 + ZBASE_SHIFT

	add	AO, AORIG, r0
	add	BO, B,     r0

	sub	TEMP, K, KK

	LFD	f16,  0 * SIZE(AO)
	LFD	f17,  1 * SIZE(AO)
	LFD	f18,  2 * SIZE(AO)
	LFD	f19,  3 * SIZE(AO)

	LFD	f20,  0 * SIZE(BO)
	LFD	f21,  1 * SIZE(BO)
	LFD	f22,  2 * SIZE(BO)
	LFD	f23,  3 * SIZE(BO)

	lfs	f0, FZERO
	fmr	f1, f0
	fmr	f2, f0
	fmr	f3, f0
	fmr	f4, f0
	fmr	f5, f0
	fmr	f6, f0
	fmr	f7, f0

	srawi.	r0, TEMP,  2
	mtspr	CTR, r0
#endif
	ble	.L45
	.align 4

.L42:
	fmadd	f0,  f16,  f20,  f0
	LFD	f23,  3 * SIZE(BO)
	fmadd	f3,  f16,  f21,  f3
	LFD	f16,  4 * SIZE(AO)
	fmadd	f2,  f17,  f20,  f2
	LFD	f20,  4 * SIZE(BO)
	fmadd	f1,  f17,  f21,  f1
	LFD	f17,  5 * SIZE(AO)

	fmadd	f4,  f18,  f22,  f4
	LFD	f21,  5 * SIZE(BO)
	fmadd	f7,  f18,  f23,  f7
	LFD	f18,  6 * SIZE(AO)
	fmadd	f6,  f19,  f22,  f6
	LFD	f22,  6 * SIZE(BO)
	fmadd	f5,  f19,  f23,  f5
	LFD	f19,  7 * SIZE(AO)

	fmadd	f0,  f16,  f20,  f0
	LFD	f23,  7 * SIZE(BO)
	fmadd	f3,  f16,  f21,  f3
	LFDU	f16,  8 * SIZE(AO)
	fmadd	f2,  f17,  f20,  f2
	LFDU	f20,  8 * SIZE(BO)
	fmadd	f1,  f17,  f21,  f1
	LFD	f17,  1 * SIZE(AO)

	fmadd	f4,  f18,  f22,  f4
	LFD	f21,  1 * SIZE(BO)
	fmadd	f7,  f18,  f23,  f7
	LFD	f18,  2 * SIZE(AO)
	fmadd	f6,  f19,  f22,  f6
	LFD	f22,  2 * SIZE(BO)
	fmadd	f5,  f19,  f23,  f5
	LFD	f19,  3 * SIZE(AO)
	bdnz	.L42
	.align 4

.L45:
	fadd	f0, f0, f4
	fadd	f1, f1, f5
	fadd	f2, f2, f6
	fadd	f3, f3, f7

#if defined(LT) || defined(RN)
	andi.	r0, KK,  3
#else
	andi.	r0, TEMP, 3
#endif
	mtspr	CTR,r0
	ble	.L47
	.align 4

.L46:
	fmadd	f0,  f16,  f20,  f0
	LFD	f21, 1 * SIZE(BO)
	fmadd	f3,  f16,  f21,  f3
	LFDU	f16, 2 * SIZE(AO)
	fmadd	f2,  f17,  f20,  f2
	LFDU	f20, 2 * SIZE(BO)
	fmadd	f1,  f17,  f21,  f1
	LFD	f17, 1 * SIZE(AO)
	bdnz	.L46
	.align 4

.L47:
#ifndef CONJ
	FSUB	  f0,  f0,  f1
	FADD	  f1,  f2,  f3
#else
	FADD	  f0,  f0,  f1
	FSUB	  f1,  f3,  f2
#endif

#if defined(LN) || defined(RT)
	subi	r0, KK, 1
	slwi	r0,   r0, 0 + ZBASE_SHIFT

	add	AO, AORIG, r0
	add	BO, B,     r0
#endif

#if defined(LN) || defined(LT)
	LFD	f16,  0 * SIZE(BO)
	LFD	f17,  1 * SIZE(BO)
	FSUB	f0,  f16, f0
	FSUB	f1,  f17, f1
#else
	LFD	f16,  0 * SIZE(AO)
	LFD	f17,  1 * SIZE(AO)
#ifndef CONJ
	FSUB	f0,  f16, f0
	FSUB	f1,  f17, f1
#else
	FSUB	f0,  f16, f0
	FADD	f1,  f17, f1
#endif
#endif

#ifdef LN
	LFD	f20,  0 * SIZE(AO)
	LFD	f21,  1 * SIZE(AO)

	FMUL	f4,  f21, f1
	FMUL	f5,  f21, f0
#ifndef CONJ
	FMSUB	f0,  f20, f0,  f4
	FMADD	f1,  f20, f1,  f5
#else
	FMADD	f0,  f20, f0,  f4
	FMSUB	f1,  f20, f1,  f5
#endif
#endif

#ifdef LT
	LFD	f16,  0 * SIZE(AO)
	LFD	f17,  1 * SIZE(AO)

	FMUL	f4,  f17, f1
	FMUL	f5,  f17, f0

#ifndef CONJ
	FMSUB	f0,  f16, f0,  f4
	FMADD	f1,  f16, f1,  f5
#else
	FMADD	f0,  f16, f0,  f4
	FMSUB	f1,  f16, f1,  f5
#endif
#endif

#ifdef RN
	LFD	f16,  0 * SIZE(BO)
	LFD	f17,  1 * SIZE(BO)

	FMUL	f4,  f17, f1
	FMUL	f5,  f17, f0
#ifndef CONJ
	FMSUB	f0,  f16, f0,  f4
	FMADD	f1,  f16, f1,  f5
#else
	FMADD	f0,  f16, f0,  f4
	FMSUB	f1,  f16, f1,  f5
#endif
#endif

#ifdef RT
	LFD	f20,  0 * SIZE(BO)
	LFD	f21,  1 * SIZE(BO)

	FMUL	f4,  f21, f1
	FMUL	f5,  f21, f0
#ifndef CONJ
	FMSUB	f0,  f20, f0,  f4
	FMADD	f1,  f20, f1,  f5
#else
	FMADD	f0,  f20, f0,  f4
	FMSUB	f1,  f20, f1,  f5
#endif
#endif

#ifdef LN
	subi	CO1, CO1, 2 * SIZE
#endif

#if defined(LN) || defined(LT)
	STFD	f0,   0 * SIZE(BO)
	STFD	f1,   1 * SIZE(BO)
#else
	STFD	f0,   0 * SIZE(AO)
	STFD	f1,   1 * SIZE(AO)
#endif

	STFD	f0,   0 * SIZE(CO1)
	STFD	f1,   1 * SIZE(CO1)

#ifndef LN
	addi	CO1, CO1, 2 * SIZE
#endif

#ifdef RT
	slwi	r0, K, 0 + ZBASE_SHIFT
	add	AORIG, AORIG, r0
#endif

#if defined(LT) || defined(RN)
	sub	TEMP, K, KK
	slwi	TEMP, TEMP, 0 + ZBASE_SHIFT
	add	AO, AO, TEMP
	add	BO, BO, TEMP
#endif

#ifdef LT
	addi	KK, KK, 1
#endif

#ifdef LN
	subi	KK, KK, 1
#endif
	.align 4

.L49:
#ifdef LN
	slwi	r0, K, 0 + ZBASE_SHIFT
	add	B, B, r0
#endif

#if defined(LT) || defined(RN)
	mr	B,  BO
#endif

#ifdef RN
	addi	KK, KK, 1
#endif

#ifdef RT
	subi	KK, KK, 1
#endif
	.align 4


.L30:	
	srawi.	J, N,  1
	ble	.L999
	.align 4

.L10:
#ifdef RT
	slwi	r0, K, 1 + ZBASE_SHIFT
	sub	B, B, r0

	slwi	r0, LDC, 1
	sub	C, C, r0
#endif

	mr	CO1, C
	add	CO2, C,  LDC

#ifdef LN
	add	KK, M, OFFSET
#endif

#ifdef LT
	mr	KK, OFFSET
#endif

	srawi.	I, M,  1
#if defined(LN) || defined(RT)
	mr	AORIG, A
#else
	mr	AO, A
#endif
#ifndef RT
	add	C,  CO2, LDC
#endif
	ble	.L20
	.align 4

.L11:
#if defined(LT) || defined(RN)
	LFD	A1,  0 * SIZE(AO)
	LFD	A2,  1 * SIZE(AO)
	LFD	A4,  4 * SIZE(AO)
	LFD	A5,  8 * SIZE(AO)

	LFD	B1,  0 * SIZE(B)
	LFD	B2,  1 * SIZE(B)
	LFD	B3,  2 * SIZE(B)
	LFD	B4,  3 * SIZE(B)
	LFD	B5,  4 * SIZE(B)
	LFD	B6,  8 * SIZE(B)
	LFD	B7, 12 * SIZE(B)

	lfs	f0,  FZERO
 	fmr	f1,  f0
	fmr	f2,  f0
	fmr	f3,  f0

	fmr	f4,  f0
	fmr	f5,  f0
	fmr	f6,  f0
	fmr	f7,  f0

	fmr	f8,  f0
	fmr	f9,  f0
	fmr	f10, f0
	fmr	f11, f0

	fmr	f12, f0
	fmr	f13, f0
	fmr	f14, f0
	fmr	f15, f0

	srawi.	r0, KK,  2
	mtspr	CTR, r0
	mr	BO,  B
#else

#ifdef LN
	slwi	r0,   K,  1 + ZBASE_SHIFT
	sub	AORIG, AORIG, r0
#endif

	slwi	TEMP, KK, 1 + ZBASE_SHIFT
	add	AO, AORIG, TEMP
	add	BO, B,     TEMP

	sub	TEMP, K, KK

	LFD	A1,  0 * SIZE(AO)
	LFD	A2,  1 * SIZE(AO)
	LFD	A4,  4 * SIZE(AO)
	LFD	A5,  8 * SIZE(AO)

	LFD	B1,  0 * SIZE(BO)
	LFD	B2,  1 * SIZE(BO)
	LFD	B3,  2 * SIZE(BO)
	LFD	B4,  3 * SIZE(BO)
	LFD	B5,  4 * SIZE(BO)
	LFD	B6,  8 * SIZE(BO)
	LFD	B7, 12 * SIZE(BO)

	lfs	f0,  FZERO
 	fmr	f1,  f0
	fmr	f2,  f0
	fmr	f3,  f0

	fmr	f4,  f0
	fmr	f5,  f0
	fmr	f6,  f0
	fmr	f7,  f0

	fmr	f8,  f0
	fmr	f9,  f0
	fmr	f10, f0
	fmr	f11, f0

	fmr	f12, f0
	fmr	f13, f0
	fmr	f14, f0
	fmr	f15, f0

	srawi.	r0, TEMP,  2
	mtspr	CTR, r0
#endif
	ble	.L15
	.align 4

.L12:
	FMADD	f0,  A1, B1, f0
	LFD	A3,  2 * SIZE(AO)
	FMADD	f4,  A1, B2, f4
	LFD	A6, 12 * SIZE(AO)
	FMADD	f8,  A1, B3, f8
	nop
	FMADD	f12, A1, B4, f12
	nop

	FMADD	f1,  A2, B1, f1
	LFD	A1,  3 * SIZE(AO)
	FMADD	f5,  A2, B2, f5
	nop
	FMADD	f9,  A2, B3, f9
	nop
	FMADD	f13, A2, B4, f13
	nop

	FMADD	f2,  A3, B1, f2
	nop
	FMADD	f6,  A3, B2, f6
	LFD	B8,  5 * SIZE(BO)
	FMADD	f10, A3, B3, f10
	LFD	B9,  6 * SIZE(BO)
	FMADD	f14, A3, B4, f14
	LFD	B10, 7 * SIZE(BO)

	FMADD	f3,  A1, B1, f3
	LFD	A2,  5 * SIZE(AO)
	FMADD	f7,  A1, B2, f7
	LFD	B1, 16 * SIZE(BO)
	FMADD	f11, A1, B3, f11
	nop
	FMADD	f15, A1, B4, f15
	nop

	FMADD	f0,  A4, B5, f0
 	LFD	A3,  6 * SIZE(AO)
	FMADD	f4,  A4, B8, f4
	LFD	A1, 16 * SIZE(AO)
	FMADD	f8,  A4, B9, f8
	nop
	FMADD	f12, A4, B10, f12
	nop

	FMADD	f1,  A2, B5, f1
	LFD	A4,  7 * SIZE(AO)
	FMADD	f5,  A2, B8, f5
	nop
	FMADD	f9,  A2, B9, f9
	nop
	FMADD	f13, A2, B10, f13
	nop

	FMADD	f2,  A3, B5, f2
	nop
	FMADD	f6,  A3, B8, f6
	LFD	B2,  9 * SIZE(BO)
	FMADD	f10, A3, B9, f10
	LFD	B3, 10 * SIZE(BO)
	FMADD	f14, A3, B10, f14
	LFD	B4, 11 * SIZE(BO)

	FMADD	f3,  A4, B5, f3
	LFD	A2,  9 * SIZE(AO)
	FMADD	f7,  A4, B8, f7
	LFD	B5, 20 * SIZE(BO)
	FMADD	f11, A4, B9, f11
	nop
	FMADD	f15, A4, B10, f15
	nop

	FMADD	f0,  A5, B6, f0
	LFD	A3, 10 * SIZE(AO)
	FMADD	f4,  A5, B2, f4
	LFD	A4, 20 * SIZE(AO)
	FMADD	f8,  A5, B3, f8
	nop
	FMADD	f12, A5, B4, f12
	nop

	FMADD	f1,  A2, B6, f1
	LFD	A5, 11 * SIZE(AO)
	FMADD	f5,  A2, B2, f5
	nop
	FMADD	f9,  A2, B3, f9
	nop
	FMADD	f13, A2, B4, f13
	nop

	FMADD	f2,  A3, B6, f2
	nop
	FMADD	f6,  A3, B2, f6
	LFD	B8, 13 * SIZE(BO)
	FMADD	f10, A3, B3, f10
	LFD	B9, 14 * SIZE(BO)
	FMADD	f14, A3, B4, f14
	LFD	B10,15 * SIZE(BO)

	FMADD	f3,  A5, B6, f3
	LFD	A2, 13 * SIZE(AO)
	FMADD	f7,  A5, B2, f7
	LFD	B6, 24 * SIZE(BO)
	FMADD	f11, A5, B3, f11
	nop
	FMADD	f15, A5, B4, f15
	nop

	FMADD	f0,  A6, B7, f0
	LFD	A3, 14 * SIZE(AO)
	FMADD	f4,  A6, B8, f4
	LFD	A5, 24 * SIZE(AO)
	FMADD	f8,  A6, B9, f8
	nop
	FMADD	f12, A6, B10, f12
	nop

	FMADD	f1,  A2, B7, f1
	LFD	A6, 15 * SIZE(AO)
	FMADD	f5,  A2, B8, f5
	nop
	FMADD	f9,  A2, B9, f9
	nop
	FMADD	f13, A2, B10, f13
	nop

	FMADD	f2,  A3, B7, f2
	addi	AO, AO, 16 * SIZE
	FMADD	f6,  A3, B8, f6
	LFD	B2, 17 * SIZE(BO)
	FMADD	f10, A3, B9, f10
	LFD	B3, 18 * SIZE(BO)
	FMADD	f14, A3, B10, f14
	LFD	B4, 19 * SIZE(BO)

	FMADD	f3,  A6, B7, f3
	LFD	A2,  1 * SIZE(AO)
	FMADD	f7,  A6, B8, f7
	LFD	B7, 28 * SIZE(BO)
	FMADD	f11, A6, B9, f11
	addi	BO, BO, 16 * SIZE
	FMADD	f15, A6, B10, f15
	bdnz	.L12
	.align 4

.L15:
#if defined(LT) || defined(RN)
	andi.	r0, KK,  3
#else
	andi.	r0, TEMP, 3
#endif
	mtspr	CTR, r0
	ble	.LKERNEL_MainFinish
	.align 4

.L16:
	FMADD	f0,  A1, B1, f0
	LFD	A3,  2 * SIZE(AO)
	FMADD	f4,  A1, B2, f4
	FMADD	f8,  A1, B3, f8
	FMADD	f12, A1, B4, f12
	LFD	A4,  3 * SIZE(AO)

	FMADD	f1,  A2, B1, f1
	FMADD	f5,  A2, B2, f5
	FMADD	f9,  A2, B3, f9
	FMADD	f13, A2, B4, f13
	LFDU	A1,  4 * SIZE(AO)

	FMADD	f2,  A3, B1, f2
	FMADD	f6,  A3, B2, f6
	FMADD	f10, A3, B3, f10
	FMADD	f14, A3, B4, f14
	LFD	A2,  1 * SIZE(AO)

	FMADD	f3,  A4, B1, f3
	LFDU	B1,  4 * SIZE(BO)
	FMADD	f7,  A4, B2, f7
	LFD	B2,  1 * SIZE(BO)
	FMADD	f11, A4, B3, f11
	LFD	B3,  2 * SIZE(BO)
	FMADD	f15, A4, B4, f15
	LFD	B4,  3 * SIZE(BO)
	bdnz	.L16
	.align 4

.LKERNEL_MainFinish:
#ifndef CONJ
	FSUB	  f0,  f0,  f5
	FADD	  f1,  f1,  f4
	FSUB	  f2,  f2,  f7
	FADD	  f3,  f3,  f6

	FSUB	  f8,  f8,  f13
	FADD	  f9,  f9,  f12
	FSUB	  f10, f10, f15
	FADD	  f11, f11, f14

#else
	FADD	  f0,  f0,  f5
	FSUB	  f1,  f4,  f1
	FADD	  f2,  f2,  f7
	FSUB	  f3,  f6,  f3

	FADD	  f8,  f8,  f13
	FSUB	  f9,  f12, f9
	FADD	  f10, f10, f15
	FSUB	  f11, f14, f11
#endif

#if defined(LN) || defined(RT)
	subi	r0, KK, 2
	slwi	r0, r0, 1 + ZBASE_SHIFT
	add	AO, AORIG, r0
	add	BO, B,     r0
#endif

#if defined(LN) || defined(LT)
	LFD	f16,  0 * SIZE(BO)
	LFD	f17,  1 * SIZE(BO)
	LFD	f18,  2 * SIZE(BO)
	LFD	f19,  3 * SIZE(BO)
 
	LFD	f20,  4 * SIZE(BO)
 	LFD	f21,  5 * SIZE(BO)
	LFD	f22,  6 * SIZE(BO)
	LFD	f23,  7 * SIZE(BO)

	FSUB	f0,  f16, f0
	FSUB	f1,  f17, f1
	FSUB	f8,  f18, f8
	FSUB	f9,  f19, f9

	FSUB	f2,  f20, f2
	FSUB	f3,  f21, f3
	FSUB	f10, f22, f10
	FSUB	f11, f23, f11
#else
	LFD	f16,  0 * SIZE(AO)
	LFD	f17,  1 * SIZE(AO)
	LFD	f18,  2 * SIZE(AO)
	LFD	f19,  3 * SIZE(AO)
 
	LFD	f20,  4 * SIZE(AO)
 	LFD	f21,  5 * SIZE(AO)
	LFD	f22,  6 * SIZE(AO)
	LFD	f23,  7 * SIZE(AO)

#ifndef CONJ
	FSUB	f0,  f16, f0
	FSUB	f1,  f17, f1
	FSUB	f2,  f18, f2
	FSUB	f3,  f19, f3

	FSUB	f8,  f20, f8
	FSUB	f9,  f21, f9
	FSUB	f10, f22, f10
	FSUB	f11, f23, f11
#else
	FSUB	f0,  f16, f0
	FADD	f1,  f17, f1
	FSUB	f2,  f18, f2
	FADD	f3,  f19, f3

	FSUB	f8,  f20, f8
	FADD	f9,  f21, f9
	FSUB	f10, f22, f10
	FADD	f11, f23, f11
#endif
#endif

#ifdef LN
	LFD	f16,  6 * SIZE(AO)
	LFD	f17,  7 * SIZE(AO)
	LFD	f18,  4 * SIZE(AO)
	LFD	f19,  5 * SIZE(AO)
	LFD	f20,  0 * SIZE(AO)
	LFD	f21,  1 * SIZE(AO)

	FMUL	f6,  f17, f3
	FMUL	f7,  f17, f2
	FMUL	f14, f17, f11
	FMUL	f15, f17, f10

#ifndef CONJ
	FMSUB	f2,  f16, f2,  f6
	FMADD	f3,  f16, f3,  f7
	FMSUB	f10, f16, f10, f14
	FMADD	f11, f16, f11, f15

	FMADD	f0,  f19, f3,  f0
	FNMSUB	f1,  f19, f2,  f1
	FMADD	f8,  f19, f11, f8
	FNMSUB	f9,  f19, f10, f9

	FNMSUB	f0,  f18, f2,  f0
	FNMSUB	f1,  f18, f3,  f1
	FNMSUB	f8,  f18, f10, f8
	FNMSUB	f9,  f18, f11, f9

	FMUL	f4,  f21, f1
	FMUL	f5,  f21, f0
	FMUL	f12, f21, f9
	FMUL	f13, f21, f8

	FMSUB	f0,  f20, f0,  f4
	FMADD	f1,  f20, f1,  f5
	FMSUB	f8,  f20, f8,  f12
	FMADD	f9,  f20, f9,  f13

#else
	FMADD	f2,  f16, f2,  f6
	FMSUB	f3,  f16, f3,  f7
	FMADD	f10, f16, f10, f14
	FMSUB	f11, f16, f11, f15

	FMSUB	f0,  f19, f3,  f0
	FNMADD	f1,  f19, f2,  f1
	FMSUB	f8,  f19, f11, f8
	FNMADD	f9,  f19, f10, f9

	FNMADD	f0,  f18, f2,  f0
	FNMADD	f1,  f18, f3,  f1
	FNMADD	f8,  f18, f10, f8
	FNMADD	f9,  f18, f11, f9

	FMUL	f4,  f21, f1
	FMUL	f5,  f21, f0
	FMUL	f12, f21, f9
	FMUL	f13, f21, f8

	FMADD	f0,  f20, f0,  f4
	FMSUB	f1,  f20, f1,  f5
	FMADD	f8,  f20, f8,  f12
	FMSUB	f9,  f20, f9,  f13
#endif
#endif

#ifdef LT
	LFD	f16,  0 * SIZE(AO)
	LFD	f17,  1 * SIZE(AO)
	LFD	f18,  2 * SIZE(AO)
	LFD	f19,  3 * SIZE(AO)
	LFD	f20,  6 * SIZE(AO)
	LFD	f21,  7 * SIZE(AO)

	FMUL	f4,  f17, f1
	FMUL	f5,  f17, f0
	FMUL	f12, f17, f9
	FMUL	f13, f17, f8

#ifndef CONJ
	FMSUB	f0,  f16, f0,  f4
	FMADD	f1,  f16, f1,  f5
	FMSUB	f8,  f16, f8,  f12
	FMADD	f9,  f16, f9,  f13

	FMADD	f2,  f19, f1, f2
	FNMSUB	f3,  f19, f0, f3
	FMADD	f10, f19, f9, f10
	FNMSUB	f11, f19, f8, f11

	FNMSUB	f2,  f18, f0,  f2
	FNMSUB	f3,  f18, f1,  f3
	FNMSUB	f10, f18, f8,  f10
	FNMSUB	f11, f18, f9,  f11

	FMUL	f4,  f21, f3
	FMUL	f5,  f21, f2
	FMUL	f12, f21, f11
	FMUL	f13, f21, f10

	FMSUB	f2,  f20, f2,  f4
	FMADD	f3,  f20, f3,  f5
	FMSUB	f10, f20, f10, f12
	FMADD	f11, f20, f11, f13

#else
	FMADD	f0,  f16, f0,  f4
	FMSUB	f1,  f16, f1,  f5
	FMADD	f8,  f16, f8,  f12
	FMSUB	f9,  f16, f9,  f13

	FMSUB	f2,  f19, f1, f2
	FNMADD	f3,  f19, f0, f3
	FMSUB	f10, f19, f9, f10
	FNMADD	f11, f19, f8, f11

	FNMADD	f2,  f18, f0,  f2
	FNMADD	f3,  f18, f1,  f3
	FNMADD	f10, f18, f8,  f10
	FNMADD	f11, f18, f9,  f11

	FMUL	f4,  f21, f3
	FMUL	f5,  f21, f2
	FMUL	f12, f21, f11
	FMUL	f13, f21, f10

	FMADD	f2,  f20, f2,  f4
	FMSUB	f3,  f20, f3,  f5
	FMADD	f10, f20, f10, f12
	FMSUB	f11, f20, f11, f13
#endif
#endif

#ifdef RN
	LFD	f16,  0 * SIZE(BO)
	LFD	f17,  1 * SIZE(BO)
	LFD	f18,  2 * SIZE(BO)
	LFD	f19,  3 * SIZE(BO)
	LFD	f20,  6 * SIZE(BO)
	LFD	f21,  7 * SIZE(BO)

	FMUL	f4,  f17, f1
	FMUL	f5,  f17, f0
	FMUL	f6,  f17, f3
	FMUL	f7,  f17, f2

#ifndef CONJ
	FMSUB	f0,  f16, f0,  f4
	FMADD	f1,  f16, f1,  f5
	FMSUB	f2,  f16, f2,  f6
	FMADD	f3,  f16, f3,  f7

	FMADD	f8,  f19, f1, f8
	FNMSUB	f9,  f19, f0, f9
	FMADD	f10, f19, f3, f10
	FNMSUB	f11, f19, f2, f11

	FNMSUB	f8,  f18, f0,  f8
	FNMSUB	f9,  f18, f1,  f9
	FNMSUB	f10, f18, f2,  f10
	FNMSUB	f11, f18, f3,  f11

	FMUL	f4,  f21, f9
	FMUL	f5,  f21, f8
	FMUL	f6,  f21, f11
	FMUL	f7,  f21, f10

	FMSUB	f8,  f20, f8,  f4
	FMADD	f9,  f20, f9,  f5
	FMSUB	f10, f20, f10, f6
	FMADD	f11, f20, f11, f7
#else
	FMADD	f0,  f16, f0,  f4
	FMSUB	f1,  f16, f1,  f5
	FMADD	f2,  f16, f2,  f6
	FMSUB	f3,  f16, f3,  f7

	FMSUB	f8,  f19, f1, f8
	FNMADD	f9,  f19, f0, f9
	FMSUB	f10, f19, f3, f10
	FNMADD	f11, f19, f2, f11

	FNMADD	f8,  f18, f0,  f8
	FNMADD	f9,  f18, f1,  f9
	FNMADD	f10, f18, f2,  f10
	FNMADD	f11, f18, f3,  f11

	FMUL	f4,  f21, f9
	FMUL	f5,  f21, f8
	FMUL	f6,  f21, f11
	FMUL	f7,  f21, f10

	FMADD	f8,  f20, f8,  f4
	FMSUB	f9,  f20, f9,  f5
	FMADD	f10, f20, f10, f6
	FMSUB	f11, f20, f11, f7
#endif
#endif

#ifdef RT
	LFD	f16,  6 * SIZE(BO)
	LFD	f17,  7 * SIZE(BO)
	LFD	f18,  4 * SIZE(BO)
	LFD	f19,  5 * SIZE(BO)
	LFD	f20,  0 * SIZE(BO)
	LFD	f21,  1 * SIZE(BO)

	FMUL	f12, f17, f9
	FMUL	f13, f17, f8
	FMUL	f14, f17, f11
	FMUL	f15, f17, f10

#ifndef CONJ
	FMSUB	f8,  f16, f8,  f12
	FMADD	f9,  f16, f9,  f13
	FMSUB	f10, f16, f10, f14
	FMADD	f11, f16, f11, f15

	FMADD	f0,  f19, f9,  f0
	FNMSUB	f1,  f19, f8,  f1
	FMADD	f2,  f19, f11, f2
	FNMSUB	f3,  f19, f10, f3

	FNMSUB	f0,  f18, f8,  f0
	FNMSUB	f1,  f18, f9,  f1
	FNMSUB	f2,  f18, f10, f2
	FNMSUB	f3,  f18, f11, f3

	FMUL	f4,  f21, f1
	FMUL	f5,  f21, f0
	FMUL	f6,  f21, f3
	FMUL	f7,  f21, f2

	FMSUB	f0,  f20, f0,  f4
	FMADD	f1,  f20, f1,  f5
	FMSUB	f2,  f20, f2,  f6
	FMADD	f3,  f20, f3,  f7

#else
	FMADD	f8,  f16, f8,  f12
	FMSUB	f9,  f16, f9,  f13
	FMADD	f10, f16, f10, f14
	FMSUB	f11, f16, f11, f15

	FMSUB	f0,  f19, f9,  f0
	FNMADD	f1,  f19, f8,  f1
	FMSUB	f2,  f19, f11, f2
	FNMADD	f3,  f19, f10, f3

	FNMADD	f0,  f18, f8,  f0
	FNMADD	f1,  f18, f9,  f1
	FNMADD	f2,  f18, f10, f2
	FNMADD	f3,  f18, f11, f3

	FMUL	f4,  f21, f1
	FMUL	f5,  f21, f0
	FMUL	f6,  f21, f3
	FMUL	f7,  f21, f2

	FMADD	f0,  f20, f0,  f4
	FMSUB	f1,  f20, f1,  f5
	FMADD	f2,  f20, f2,  f6
	FMSUB	f3,  f20, f3,  f7
#endif
#endif

#ifdef LN
	subi	CO1, CO1, 4 * SIZE
	subi	CO2, CO2, 4 * SIZE
#endif

#if defined(LN) || defined(LT)
	STFD	f0,   0 * SIZE(BO)
	STFD	f1,   1 * SIZE(BO)
	STFD	f8,   2 * SIZE(BO)
	STFD	f9,   3 * SIZE(BO)

	STFD	f2,   4 * SIZE(BO)
	STFD	f3,   5 * SIZE(BO)
	STFD	f10,  6 * SIZE(BO)
	STFD	f11,  7 * SIZE(BO)
#else
	STFD	f0,   0 * SIZE(AO)
	STFD	f1,   1 * SIZE(AO)
	STFD	f2,   2 * SIZE(AO)
	STFD	f3,   3 * SIZE(AO)

	STFD	f8,   4 * SIZE(AO)
	STFD	f9,   5 * SIZE(AO)
	STFD	f10,  6 * SIZE(AO)
	STFD	f11,  7 * SIZE(AO)
#endif

	STFD	f0,   0 * SIZE(CO1)
	STFD	f1,   1 * SIZE(CO1)
	STFD	f2,   2 * SIZE(CO1)
	STFD	f3,   3 * SIZE(CO1)

	STFD	f8,   0 * SIZE(CO2)
	STFD	f9,   1 * SIZE(CO2)
	STFD	f10,  2 * SIZE(CO2)
	STFD	f11,  3 * SIZE(CO2)

#ifndef LN
	addi	CO1, CO1, 4 * SIZE
	addi	CO2, CO2, 4 * SIZE
#endif
	
#ifdef RT
	slwi	r0, K, 1 + ZBASE_SHIFT
	add	AORIG, AORIG, r0
#endif

#if defined(LT) || defined(RN)
	sub	TEMP, K, KK
	slwi	TEMP, TEMP, 1 + ZBASE_SHIFT
	add	AO, AO, TEMP
	add	BO, BO, TEMP
#endif

#ifdef LT
	addi	KK, KK, 2
#endif

#ifdef LN
	subi	KK, KK, 2
#endif

	addic.	I, I, -1
	bgt	.L11
	.align 4

.L20:
	andi.	I,  M,  1
	ble	.L29

#if defined(LT) || defined(RN)
	LFD	f16,  0 * SIZE(AO)
	LFD	f17,  1 * SIZE(AO)
	LFD	f18,  2 * SIZE(AO)
	LFD	f19,  3 * SIZE(AO)

	LFD	f20,  0 * SIZE(B)
	LFD	f21,  1 * SIZE(B)
	LFD	f22,  2 * SIZE(B)
	LFD	f23,  3 * SIZE(B)

	LFD	f24,  4 * SIZE(B)
	LFD	f25,  5 * SIZE(B)
	LFD	f26,  6 * SIZE(B)
	LFD	f27,  7 * SIZE(B)

	lfs	f0,  FZERO
 	fmr	f1,  f0
	fmr	f2,  f0
	fmr	f3,  f0

	fmr	f4,  f0
	fmr	f5,  f0
	fmr	f6,  f0
	fmr	f7,  f0

	srawi.	r0, KK,  2
	mr	BO,  B
	mtspr	CTR, r0
#else

#ifdef LN
	slwi	r0,   K,  0 + ZBASE_SHIFT
	sub	AORIG, AORIG, r0
#endif

	slwi	r0,   KK, 0 + ZBASE_SHIFT
	slwi	TEMP, KK, 1 + ZBASE_SHIFT
	add	AO, AORIG, r0
	add	BO, B,     TEMP

	sub	TEMP, K, KK

	LFD	f16,  0 * SIZE(AO)
	LFD	f17,  1 * SIZE(AO)
	LFD	f18,  2 * SIZE(AO)
	LFD	f19,  3 * SIZE(AO)

	LFD	f20,  0 * SIZE(BO)
	LFD	f21,  1 * SIZE(BO)
	LFD	f22,  2 * SIZE(BO)
	LFD	f23,  3 * SIZE(BO)

	LFD	f24,  4 * SIZE(BO)
	LFD	f25,  5 * SIZE(BO)
	LFD	f26,  6 * SIZE(BO)
	LFD	f27,  7 * SIZE(BO)

	lfs	f0,  FZERO
 	fmr	f1,  f0
	fmr	f2,  f0
	fmr	f3,  f0

	fmr	f4,  f0
	fmr	f5,  f0
	fmr	f6,  f0
	fmr	f7,  f0

	srawi.	r0, TEMP,  2
	mtspr	CTR, r0
#endif
	ble	.L25
	.align 4

.L22:
	fmadd	f0,  f16, f20, f0
	LFD	f19,  3 * SIZE(AO)
	fmadd	f1,  f16, f21, f1
	nop
	fmadd	f2,  f16, f22, f2
	nop
	fmadd	f3,  f16, f23, f3
	LFD	f16,  4 * SIZE(AO)

	fmadd	f4,  f17, f20, f4
 	LFD	f20,  8 * SIZE(BO)
	fmadd	f5,  f17, f21, f5
	LFD	f21,  9 * SIZE(BO)
	fmadd	f6,  f17, f22, f6
	LFD	f22, 10 * SIZE(BO)
	fmadd	f7,  f17, f23, f7
	LFD	f23, 11 * SIZE(BO)

	fmadd	f0,  f18, f24, f0
	LFD	f17,  5 * SIZE(AO)
	fmadd	f1,  f18, f25, f1
	nop
	fmadd	f2,  f18, f26, f2
	nop
	fmadd	f3,  f18, f27, f3
	LFD	f18,  6 * SIZE(AO)

	fmadd	f4,  f19, f24, f4
 	LFD	f24, 12 * SIZE(BO)
	fmadd	f5,  f19, f25, f5
	LFD	f25, 13 * SIZE(BO)
	fmadd	f6,  f19, f26, f6
	LFD	f26, 14 * SIZE(BO)
	fmadd	f7,  f19, f27, f7
	LFD	f27, 15 * SIZE(BO)

	fmadd	f0,  f16, f20, f0
	LFD	f19,  7 * SIZE(AO)
	fmadd	f1,  f16, f21, f1
	nop
	fmadd	f2,  f16, f22, f2
	nop
	fmadd	f3,  f16, f23, f3
	LFDU	f16,  8 * SIZE(AO)

	fmadd	f4,  f17, f20, f4
 	LFDU	f20, 16 * SIZE(BO)
	fmadd	f5,  f17, f21, f5
	LFD	f21,  1 * SIZE(BO)
	fmadd	f6,  f17, f22, f6
	LFD	f22,  2 * SIZE(BO)
	fmadd	f7,  f17, f23, f7
	LFD	f23,  3 * SIZE(BO)

	fmadd	f0,  f18, f24, f0
	LFD	f17,  1 * SIZE(AO)
	fmadd	f1,  f18, f25, f1
	nop
	fmadd	f2,  f18, f26, f2
	nop
	fmadd	f3,  f18, f27, f3
	LFD	f18,  2 * SIZE(AO)

	fmadd	f4,  f19, f24, f4
 	LFD	f24,  4 * SIZE(BO)
	fmadd	f5,  f19, f25, f5
	LFD	f25,  5 * SIZE(BO)
	fmadd	f6,  f19, f26, f6
	LFD	f26,  6 * SIZE(BO)
	fmadd	f7,  f19, f27, f7
	LFD	f27,  7 * SIZE(BO)
	bdnz	.L22
	.align 4

.L25:
#if defined(LT) || defined(RN)
	andi.	r0, KK,  3
#else
	andi.	r0, TEMP, 3
#endif
	mtspr	CTR, r0
	ble	.L27
	.align 4

.L26:
	fmadd	f0,  f16, f20, f0
	LFD	f17,  1 * SIZE(AO)
	fmadd	f1,  f16, f21, f1
	nop
	fmadd	f2,  f16, f22, f2
	nop
	fmadd	f3,  f16, f23, f3
	LFDU	f16,  2 * SIZE(AO)

	fmadd	f4,  f17, f20, f4
 	LFDU	f20,  4 * SIZE(BO)
	fmadd	f5,  f17, f21, f5
	LFD	f21,  1 * SIZE(BO)
	fmadd	f6,  f17, f22, f6
	LFD	f22,  2 * SIZE(BO)
	fmadd	f7,  f17, f23, f7
	LFD	f23,  3 * SIZE(BO)
	bdnz	.L26
	.align 4

.L27:
#ifndef CONJ
	FSUB	  f0,  f0,  f5
	FADD	  f1,  f1,  f4
	FSUB	  f2,  f2,  f7
	FADD	  f3,  f3,  f6
#else
#if defined(LN) || defined(LT)
	FADD	  f0,  f0,  f5
	FSUB	  f1,  f1,  f4
	FADD	  f2,  f2,  f7
	FSUB	  f3,  f3,  f6
#else
	FADD	  f0,  f0,  f5
	FSUB	  f1,  f4,  f1
	FADD	  f2,  f2,  f7
	FSUB	  f3,  f6,  f3
#endif
#endif

#if defined(LN) || defined(RT)
#ifdef LN
	subi	r0, KK, 1
#else
	subi	r0, KK, 2
#endif
	slwi	TEMP, r0, 0 + ZBASE_SHIFT
	slwi	r0,   r0, 1 + ZBASE_SHIFT
	add	AO, AORIG, TEMP
	add	BO, B,     r0
#endif


#if defined(LN) || defined(LT)
	LFD	f16,  0 * SIZE(BO)
	LFD	f17,  1 * SIZE(BO)
	LFD	f18,  2 * SIZE(BO)
	LFD	f19,  3 * SIZE(BO)

	FSUB	f0,  f16, f0
	FSUB	f1,  f17, f1
	FSUB	f2,  f18, f2
	FSUB	f3,  f19, f3
#else
	LFD	f16,  0 * SIZE(AO)
	LFD	f17,  1 * SIZE(AO)
	LFD	f20,  2 * SIZE(AO)
 	LFD	f21,  3 * SIZE(AO)

	FSUB	f0,  f16, f0
	FSUB	f1,  f17, f1
	FSUB	f2,  f20, f2
	FSUB	f3,  f21, f3
#endif

#ifdef LN
	LFD	f20,  0 * SIZE(AO)
	LFD	f21,  1 * SIZE(AO)

	FMUL	f4,  f21, f1
	FMUL	f5,  f21, f0
	FMUL	f12, f21, f3
	FMUL	f13, f21, f2

#ifndef CONJ
	FMSUB	f0,  f20, f0,  f4
	FMADD	f1,  f20, f1,  f5
	FMSUB	f2,  f20, f2,  f12
	FMADD	f3,  f20, f3,  f13
#else
	FMADD	f0,  f20, f0,  f4
	FMSUB	f1,  f20, f1,  f5
	FMADD	f2,  f20, f2,  f12
	FMSUB	f3,  f20, f3,  f13
#endif
#endif

#ifdef LT
	LFD	f16,  0 * SIZE(AO)
	LFD	f17,  1 * SIZE(AO)

	FMUL	f4,  f17, f1
	FMUL	f5,  f17, f0
	FMUL	f12, f17, f3
	FMUL	f13, f17, f2

#ifndef CONJ
	FMSUB	f0,  f16, f0,  f4
	FMADD	f1,  f16, f1,  f5
	FMSUB	f2,  f16, f2,  f12
	FMADD	f3,  f16, f3,  f13
#else
	FMADD	f0,  f16, f0,  f4
	FMSUB	f1,  f16, f1,  f5
	FMADD	f2,  f16, f2,  f12
	FMSUB	f3,  f16, f3,  f13
#endif
#endif

#ifdef RN
	LFD	f16,  0 * SIZE(BO)
	LFD	f17,  1 * SIZE(BO)
	LFD	f18,  2 * SIZE(BO)
	LFD	f19,  3 * SIZE(BO)
	LFD	f20,  6 * SIZE(BO)
	LFD	f21,  7 * SIZE(BO)

	FMUL	f4,  f17, f1
	FMUL	f5,  f17, f0

#ifndef CONJ
	FMSUB	f0,  f16, f0,  f4
	FMADD	f1,  f16, f1,  f5

	FMADD	f2,  f19, f1, f2
	FNMSUB	f3,  f19, f0, f3

	FNMSUB	f2,  f18, f0,  f2
	FNMSUB	f3,  f18, f1,  f3

	FMUL	f4,  f21, f3
	FMUL	f5,  f21, f2

	FMSUB	f2,  f20, f2,  f4
	FMADD	f3,  f20, f3,  f5
#else
	FMADD	f0,  f16, f0,  f4
	FMSUB	f1,  f16, f1,  f5

	FMSUB	f2,  f19, f1, f2
	FNMADD	f3,  f19, f0, f3

	FNMADD	f2,  f18, f0,  f2
	FNMADD	f3,  f18, f1,  f3

	FMUL	f4,  f21, f3
	FMUL	f5,  f21, f2

	FMADD	f2,  f20, f2,  f4
	FMSUB	f3,  f20, f3,  f5
#endif
#endif

#ifdef RT
	LFD	f16,  6 * SIZE(BO)
	LFD	f17,  7 * SIZE(BO)
	LFD	f18,  4 * SIZE(BO)
	LFD	f19,  5 * SIZE(BO)
	LFD	f20,  0 * SIZE(BO)
	LFD	f21,  1 * SIZE(BO)

	FMUL	f12, f17, f3
	FMUL	f13, f17, f2

#ifndef CONJ
	FMSUB	f2,  f16, f2,  f12
	FMADD	f3,  f16, f3,  f13

	FMADD	f0,  f19, f3,  f0
	FNMSUB	f1,  f19, f2,  f1

	FNMSUB	f0,  f18, f2,  f0
	FNMSUB	f1,  f18, f3,  f1

	FMUL	f4,  f21, f1
	FMUL	f5,  f21, f0

	FMSUB	f0,  f20, f0,  f4
	FMADD	f1,  f20, f1,  f5
#else
	FMADD	f2,  f16, f2,  f12
	FMSUB	f3,  f16, f3,  f13

	FMSUB	f0,  f19, f3,  f0
	FNMADD	f1,  f19, f2,  f1

	FNMADD	f0,  f18, f2,  f0
	FNMADD	f1,  f18, f3,  f1

	FMUL	f4,  f21, f1
	FMUL	f5,  f21, f0

	FMADD	f0,  f20, f0,  f4
	FMSUB	f1,  f20, f1,  f5
#endif
#endif

#ifdef LN
	subi	CO1, CO1, 2 * SIZE
	subi	CO2, CO2, 2 * SIZE
#endif

#if defined(LN) || defined(LT)
	STFD	f0,   0 * SIZE(BO)
	STFD	f1,   1 * SIZE(BO)
	STFD	f2,   2 * SIZE(BO)
	STFD	f3,   3 * SIZE(BO)
#else
	STFD	f0,   0 * SIZE(AO)
	STFD	f1,   1 * SIZE(AO)
	STFD	f2,   2 * SIZE(AO)
	STFD	f3,   3 * SIZE(AO)
#endif

	STFD	f0,   0 * SIZE(CO1)
	STFD	f1,   1 * SIZE(CO1)
	STFD	f2,   0 * SIZE(CO2)
	STFD	f3,   1 * SIZE(CO2)

#ifndef LN
	addi	CO1, CO1, 2 * SIZE
	addi	CO2, CO2, 2 * SIZE
#endif

#ifdef RT
	slwi	r0, K, 0 + ZBASE_SHIFT
	add	AORIG, AORIG, r0
#endif

#if defined(LT) || defined(RN)
	sub	TEMP, K, KK
	slwi	r0,   TEMP, 0 + ZBASE_SHIFT
	slwi	TEMP, TEMP, 1 + ZBASE_SHIFT
	add	AO, AO, r0
	add	BO, BO, TEMP
#endif

#ifdef LT
	addi	KK, KK, 1
#endif

#ifdef LN
	subi	KK, KK, 1
#endif
	.align 4

.L29:
#ifdef LN
	slwi	r0, K, 1 + ZBASE_SHIFT
	add	B, B, r0
#endif

#if defined(LT) || defined(RN)
	mr	B,  BO
#endif

#ifdef RN
	addi	KK, KK, 2
#endif

#ifdef RT
	subi	KK, KK, 2
#endif

	addic.	J, J, -1
	bgt	.L10
	.align 4


.L999:
	addi	r3, 0, 0

	lfd	f14,    0(SP)
	lfd	f15,    8(SP)
	lfd	f16,   16(SP)
	lfd	f17,   24(SP)

	lfd	f18,   32(SP)
	lfd	f19,   40(SP)
	lfd	f20,   48(SP)
	lfd	f21,   56(SP)

	lfd	f22,   64(SP)
	lfd	f23,   72(SP)
	lfd	f24,   80(SP)
	lfd	f25,   88(SP)

	lfd	f26,   96(SP)
	lfd	f27,  104(SP)
	lfd	f28,  112(SP)
	lfd	f29,  120(SP)

	lfd	f30,  128(SP)
	lfd	f31,  136(SP)

#ifdef __64BIT__
	ld	r31,  144(SP)
	ld	r30,  152(SP)
	ld	r29,  160(SP)
	ld	r28,  168(SP)
	ld	r27,  176(SP)
	ld	r26,  184(SP)
	ld	r25,  192(SP)
	ld	r24,  200(SP)
	ld	r23,  208(SP)
	ld	r22,  216(SP)
	ld	r21,  224(SP)
#else
	lwz	r31,  144(SP)
	lwz	r30,  148(SP)
	lwz	r29,  152(SP)
	lwz	r28,  156(SP)
	lwz	r27,  160(SP)
	lwz	r26,  164(SP)
	lwz	r25,  168(SP)
	lwz	r24,  172(SP)
	lwz	r23,  176(SP)
	lwz	r22,  180(SP)
	lwz	r21,  184(SP)
#endif

	addi	SP, SP, STACKSIZE

	blr

	EPILOGUE
