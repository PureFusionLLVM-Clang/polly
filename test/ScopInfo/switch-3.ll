; RUN: opt %loadPolly -polly-detect-unprofitable -polly-scops -analyze < %s | FileCheck %s
; RUN: opt %loadPolly -polly-detect-unprofitable -polly-ast -analyze < %s | FileCheck %s --check-prefix=AST
;
;    void f(int *A, int N) {
;      for (int i = 0; i < N; i++)
;        switch (i % 4) {
;        case 0:
;          A[i] += 1;
;        case 1:
;          A[i] += 2;
;          break;
;        case 2:
;          A[i] += 3;
;        case 3:
;          A[i] += 4;
;          break;
;        }
;    }
;
; CHECK:    Statements {
; CHECK:      Stmt_sw_bb_5
; CHECK:            Domain :=
; CHECK:                [N] -> { Stmt_sw_bb_5[i0] : exists (e0 = floor((-2 + i0)/4): 4e0 = -2 + i0 and i0 >= 2 and i0 <= -1 + N) };
; CHECK:            Schedule :=
; CHECK:                [N] -> { Stmt_sw_bb_5[i0] -> [i0, 0] };
; CHECK:      Stmt_sw_bb_9
; CHECK:            Domain :=
; CHECK:                [N] -> { Stmt_sw_bb_9[i0] : exists (e0 = floor((i0)/4): i0 >= 0 and i0 <= -1 + N and 4e0 >= -3 + i0 and 4e0 <= -2 + i0) };
; CHECK:            Schedule :=
; CHECK:                [N] -> { Stmt_sw_bb_9[i0] -> [i0, 1] };
; CHECK:      Stmt_sw_bb
; CHECK:            Domain :=
; CHECK:                [N] -> { Stmt_sw_bb[i0] : exists (e0 = floor((i0)/4): 4e0 = i0 and i0 >= 0 and i0 <= -1 + N) };
; CHECK:            Schedule :=
; CHECK:                [N] -> { Stmt_sw_bb[i0] -> [i0, 2] };
; CHECK:      Stmt_sw_bb_1
; CHECK:            Domain :=
; CHECK:                [N] -> { Stmt_sw_bb_1[i0] : exists (e0 = floor((2 + i0)/4): i0 >= 0 and i0 <= -1 + N and 4e0 >= -1 + i0 and 4e0 <= i0) };
; CHECK:            Schedule :=
; CHECK:                [N] -> { Stmt_sw_bb_1[i0] -> [i0, 3] };
; CHECK:    }
;
; AST:  if (1)
;
; AST:      for (int c0 = 0; c0 < N; c0 += 1) {
; AST:        if ((c0 - 2) % 4 == 0)
; AST:          Stmt_sw_bb_5(c0);
; AST:        if (c0 % 4 >= 2) {
; AST:          Stmt_sw_bb_9(c0);
; AST:        } else {
; AST:          if (c0 % 4 == 0)
; AST:            Stmt_sw_bb(c0);
; AST:          Stmt_sw_bb_1(c0);
; AST:        }
; AST:      }
;
; AST:  else
; AST:      {  /* original code */ }
;
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

define void @f(i32* %A, i32 %N) {
entry:
  %tmp = sext i32 %N to i64
  br label %for.cond

for.cond:                                         ; preds = %for.inc, %entry
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.inc ], [ 0, %entry ]
  %cmp = icmp slt i64 %indvars.iv, %tmp
  br i1 %cmp, label %for.body, label %for.end

for.body:                                         ; preds = %for.cond
  %tmp1 = trunc i64 %indvars.iv to i32
  %rem = srem i32 %tmp1, 4
  switch i32 %rem, label %sw.epilog [
    i32 0, label %sw.bb
    i32 1, label %sw.bb.1
    i32 2, label %sw.bb.5
    i32 3, label %sw.bb.9
  ]

sw.bb:                                            ; preds = %for.body
  %arrayidx = getelementptr inbounds i32, i32* %A, i64 %indvars.iv
  %tmp2 = load i32, i32* %arrayidx, align 4
  %add = add nsw i32 %tmp2, 1
  store i32 %add, i32* %arrayidx, align 4
  br label %sw.bb.1

sw.bb.1:                                          ; preds = %sw.bb, %for.body
  %arrayidx3 = getelementptr inbounds i32, i32* %A, i64 %indvars.iv
  %tmp3 = load i32, i32* %arrayidx3, align 4
  %add4 = add nsw i32 %tmp3, 2
  store i32 %add4, i32* %arrayidx3, align 4
  br label %sw.epilog

sw.bb.5:                                          ; preds = %for.body
  %arrayidx7 = getelementptr inbounds i32, i32* %A, i64 %indvars.iv
  %tmp4 = load i32, i32* %arrayidx7, align 4
  %add8 = add nsw i32 %tmp4, 3
  store i32 %add8, i32* %arrayidx7, align 4
  br label %sw.bb.9

sw.bb.9:                                          ; preds = %sw.bb.5, %for.body
  %arrayidx11 = getelementptr inbounds i32, i32* %A, i64 %indvars.iv
  %tmp5 = load i32, i32* %arrayidx11, align 4
  %add12 = add nsw i32 %tmp5, 4
  store i32 %add12, i32* %arrayidx11, align 4
  br label %sw.epilog

sw.epilog:                                        ; preds = %sw.bb.9, %sw.bb.1, %for.body
  br label %for.inc

for.inc:                                          ; preds = %sw.epilog
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  br label %for.cond

for.end:                                          ; preds = %for.cond
  ret void
}
