From Coq
     Require Import ZArith.ZArith.
From Ssreflect
     Require Import ssreflect ssrbool eqtype ssrnat seq tuple fintype ssrfun.
From Bits
     Require Import spec.spec spec.operations spec.operations.properties.

(* TODO:
     * Complete missing lemmas

     * Fix invalid extractions (addition is wrong on 63bits arch, for instance)

     * Define as a functor over wordsize (and forallInt) and
       instanciate at 8, 16, and 32 bits 

     * Implement an efficient [forall] for bitvectors, prove
       equivalence with finType's forall.

     * Either get an efficient version of the tests below, or
       implement them in OCaml

*)

(** * An axiomatization of OCaml native integers *)


Definition wordsize := 8.

Axiom Int: Type.
Extract Inlined Constant Int => "int".


(* Our trusted computing base sums up in these two operations and
their associated  reflection principles in Coq. *)

Axiom forallInt : (Int -> bool) -> bool.
Extract Inlined Constant forallInt => "forall_int".

Axiom eq: Int -> Int -> bool.
Extract Inlined Constant eq => "(=)".

Section Trust.

(* Axiom 1: Equality of integer is embedded within Coq's propositional equality: *)
Axiom eqIntP : Equality.axiom eq.

Variables (P : pred Int) (PP : Int -> Prop).
Hypothesis viewP : forall x, reflect (PP x) (P x).

(* Axiom 2: If a property is true for all integers, then it is propositionally true *)
Axiom forallIntP : reflect (forall x, PP x) (forallInt (fun x => P x)).

End Trust.

(* All the axiomatized properties below are exhautively tested. *)

Axiom zero : Int.
Extract Inlined Constant zero => "0".

Axiom one : Int.
Extract Inlined Constant one => "1".

Axiom succ : Int -> Int.
Extract Constant succ => "(fun x -> x + 1)".

Axiom lor: Int -> Int -> Int.
Extract Inlined Constant lor => "(lor)".

Axiom lsl: Int -> Int -> Int.
Extract Inlined Constant lsl => "(lsl)".

Axiom land: Int -> Int -> Int.
Extract Inlined Constant land => "(land)".

Axiom lt: Int -> Int -> bool.
Extract Inlined Constant lt => "(<)".

Axiom lsr: Int -> Int -> Int.
Extract Inlined Constant lsr => "(lsr)".

Axiom neg: Int -> Int.
Extract Inlined Constant neg => "-".

Axiom lnot: Int -> Int.
Extract Inlined Constant lnot => "lnot".

Axiom lxor: Int -> Int -> Int.
Extract Inlined Constant lxor => "(lxor)".

Axiom dec: Int -> Int.
Extract Constant dec => "(fun x -> x - 1)".

Axiom add: Int -> Int -> Int.
Extract Inlined Constant add => "(+)".

(* Conversion between machine integers and bit vectors *)

Fixpoint PtoInt (p: seq bool): Int :=
  match p with
    | true :: p => lor one (lsl (PtoInt p) one)
    | false :: p => lsl (PtoInt p) one
    | [::] => zero
  end.

Definition toInt (bs: BITS wordsize): Int :=
  match splitmsb bs with
    | (false, bs') => PtoInt bs'
    | (true, bs') => neg (PtoInt (negB bs))
  end.

Fixpoint fromIntS (k: nat)(n: Int): seq bool :=
  match k with
    | 0 => [::]
    | k.+1 =>
      let p := fromIntS k (lsr n one) in
      (eq (land n one) one) :: p                           
  end.

Lemma fromIntP {k} (n: Int): size (fromIntS k n) == k.
Proof.
  elim: k n => // [k IH] n //=.
  rewrite eqSS //.
Qed.

Canonical fromInt (n: Int): BITS wordsize
  := Tuple (fromIntP n).

(** * Cancelation of [toInt] on [fromInt] *)

Definition toIntK_test: bool :=
 [forall bs , fromInt (toInt bs) == bs ].

(* Validation condition:
    Experimentally, [toInt] must be cancelled by [fromInt] *)
Axiom toIntK_valid: toIntK_test.

Lemma toIntK: cancel toInt fromInt.
Proof.
  move=> bs; apply/eqP; move: bs.
  by apply/forallP: toIntK_valid.
Qed.

(** * Injectivity of [fromInt] *)

Definition fromInt_inj_test: bool := 
  forallInt (fun x =>
    forallInt (fun y => 
      (fromInt x == fromInt y) ==> (eq x y))).

(* Validation condition:
   Experimentally, [fromInt] must be injective *)
Axiom fromInt_inj_valid: fromInt_inj_test.

Lemma fromInt_inj: injective fromInt.
Proof.
  move=> x y /eqP H.
  apply/eqIntP.
  move: H; apply/implyP.
  move: x; apply/(forallIntP (fun x => (fromInt x == fromInt y) ==> eq x y)).
  move: y; apply/forallIntP. 
  exact: fromInt_inj_valid.
Qed.

Lemma fromIntK: cancel fromInt toInt.
Proof.
  apply: inj_can_sym; auto using toIntK, fromInt_inj.
Qed.

(** * Bijection [Int] vs. [BITS wordsize] *)

Lemma fromInt_bij: bijective fromInt.
Proof.
  split with (g := toInt);
  auto using toIntK, fromIntK.
Qed.


(** * Representation relation *)

(** We say that an [n : Int] is the representation of a bitvector
[bs : BITS ] if they satisfy the axiom [repr_native]. Morally, it
means that both represent the same number (ie. the same 
booleans). *)

Definition native_repr (i: Int)(bs: BITS wordsize): bool
  := eq i (toInt bs).

(** * Representation lemma: equality *)

Lemma eq_adj: forall i bs, eq i (toInt bs) = (fromInt i == bs) .
Proof.
  move=> i bs.
  apply/eqIntP/eqP; intro; subst;
  auto using fromIntK, toIntK.
Qed.
  
Lemma eq_repr:
  forall i i' bs bs',
    native_repr i bs -> native_repr i' bs' ->
    (eq i i') = (bs == bs').
Proof.
  move=> i i' bs bs'.
  rewrite /native_repr.
  repeat (rewrite eq_adj; move/eqP=> <-).
  apply/eqIntP/eqP; intro; subst; auto using fromInt_inj.
Qed.

(** * Representation lemma: individuals *)

Definition zero_test: bool 
  := eq zero (toInt #0).
  
(* Validation condition:
   bit vector [#0] corresponds to machine [0] *)
Axiom zero_valid: zero_test.

Lemma zero_repr: native_repr zero #0.
Proof. apply zero_valid. Qed.
  
Definition one_test: bool
  := eq one (toInt #1).

(* Validation condition:
   bit vector [#1] corresponds to machine [1] *)
Axiom one_valid: one_test.

Lemma one_repr: native_repr one #1.
Proof. apply one_valid. Qed.

(** * Representation lemma: successor *)

Definition succ_test: bool
  := forallInt (fun i =>
     native_repr (succ i) (incB (fromInt i))).

(* Validation condition:
    [succ "n"] corresponds to machine [n + 1] *)
Axiom succ_valid: succ_test.

Lemma succ_repr: forall i bs,
    native_repr i bs -> native_repr (succ i) (incB bs).
Proof.
  move=> i ?.
  rewrite /native_repr eq_adj.
  move/eqP=> <-.
  apply/eqIntP.
  move: i; apply/forallIntP.
  apply succ_valid.
Qed.

(** * Representation lemma: negation *)

Definition lnot_test: bool
  := forallInt (fun i =>
       native_repr (lnot i) (invB (fromInt i))).

(* Validation condition:
    [invB "n"] corresponds to machine [lnot n] *)
Axiom lnot_valid: lnot_test.

Lemma lnot_repr: forall i bs,
    native_repr i bs -> native_repr (lnot i) (invB bs).
Proof.
  move=> i ?.
  rewrite /native_repr eq_adj.
  move/eqP=> <-.
  apply/eqIntP.
  move: i; apply/forallIntP.
  apply lnot_valid.
Qed.

(** * Representation lemma: logical and *)

Definition land_test: bool
  := forallInt (fun i =>
       forallInt (fun i' =>
         native_repr (land i i') (andB (fromInt i) (fromInt i')))).

(* Validation condition:
    [land "m" "n"] corresponds to machine [m land n] *)
Axiom land_valid: land_test.

Lemma land_repr: forall i i' bs bs',
    native_repr i bs -> native_repr i' bs' ->
    native_repr (land i i') (andB bs bs').
Proof.
  move=> i i' ? ?.
  repeat (rewrite /native_repr eq_adj; move/eqP=> <-).
  apply/eqIntP.
  move: i'; apply/(forallIntP (fun i' => eq (land i i') (toInt (andB (fromInt i) (fromInt i'))))).
  move: i; apply/forallIntP.
  apply land_valid.
Qed.

(** * Representation lemma: logical or *)

Definition lor_test: bool. Admitted.

(* Validation condition:
    [lor "m" "n"] corresponds to machine [m lor n] *)
Axiom lor_valid: lor_test.

Lemma lor_repr: forall i i' bs bs',
    native_repr i bs -> native_repr i' bs' ->
    native_repr (lor i i') (orB bs bs').
Admitted.

(** * Representation lemma: logical xor *)

Definition lxor_test: bool. Admitted.

(* Validation condition:
    [lxor "m" "n"] corresponds to machine [m lxor n] *)
Axiom lxor_valid: lxor_test.


Lemma lxor_repr: forall i i' bs bs',
    native_repr i bs -> native_repr i' bs' ->
    native_repr (lxor i i') (xorB bs bs').
Admitted. 

(** * Representation of naturals *)

(** We extend the refinement relation (by composition) to natural
numbers, going through a [BITS wordsize] word. *)

Definition natural_repr (i: Int)(n: nat): bool :=
  [exists bs, native_repr i bs && (# n == bs)].

(** * Representation lemma: logical shift right *)

(* TODO: this one might be tricky: get nat on one side, int on the other *)
Definition lsr_test: bool. Admitted.

(* Validation condition:
    [lsr "m" "n"] corresponds to machine [m lsr n] *)
Axiom lsr_valid: lsr_test.

Lemma lsr_repr: forall i j bs k,
    native_repr i bs -> natural_repr j k ->
    native_repr (lsr i j) (shrBn bs k).
Admitted.

(** * Representation lemma: logical shift left *)

(* TODO: this one might be tricky: get nat on one side, int on the other *)

Definition lsl_test: bool. Admitted.

(* Validation condition:
    [lsl "m" "n"] corresponds to machine [m lsl n] *)
Axiom lsl_valid: lsl_test.

Lemma lsl_repr: forall i j bs k,
    native_repr i bs -> natural_repr j k ->
    native_repr (lsl i j) (shlBn bs k).
Admitted.

(** * Representation lemma: negation *)

Definition lneg_test: bool. Admitted.

(* Validation condition:
    [negB "m"] corresponds to machine [- m] *)
Axiom lneg_valid: lneg_test.

Lemma lneg_repr: forall i bs,
    native_repr i bs -> native_repr (neg i) (negB bs).
Admitted.

(** * Representation lemma: decrement *)

Definition dec_test: bool. Admitted.

(* Validation condition:
    [decB "m"] corresponds to machine [dec m] *)
Axiom dec_valid: dec_test.

Lemma dec_repr: forall i bs,
    native_repr i bs -> native_repr (dec i) (decB bs).
Admitted.

(** * Representation lemma: addition *)

Definition add_test: bool. Admitted.

(* Validation condition:
    [decB "m"] corresponds to machine [dec m] *)
Axiom add_valid: add_test.

Lemma add_repr:
  forall i i' bs bs',
    native_repr i bs -> native_repr i' bs' ->
    native_repr (add i i') (addB bs bs').
Admitted.


(** Extract the tests: they should all return true! *)

Require Import ExtrOcamlBasic.


Definition tests
  := foldr (andb) true [:: toIntK_test ;
                         fromInt_inj_test ;
                         zero_test ;
                         one_test ;
                         succ_test ;
                         lnot_test ; 
                         land_test ;
                         lor_test ;
                         lxor_test ;
                         lsr_test ;
                         lsl_test ;
                         lneg_test ;
                         dec_test ;
                         add_test ].

Extraction "axioms.ml"  tests. 