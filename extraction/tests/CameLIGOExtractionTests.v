(** * Extraction of various contracts to CameLIGO *)

From Coq Require Import Lia.
From Coq Require Import List.
From Coq Require Import String.
From MetaCoq.Template Require Import All.
From ConCert.Extraction Require Import Common.
From ConCert.Extraction Require Import CameLIGOPretty.
From ConCert.Extraction Require Import CameLIGOExtract.

Import MonadNotation.

Local Open Scope string_scope.

Existing Instance PrintConfShortNames.PrintWithShortNames.

Definition bindOptCont {A B} (a : option A) (f : A -> option B) : option B :=
  match a with
  | Some a => f a
  | None => None
  end.

Module FoldLeft.

  (** We test how the annotation machinery passes the context with erased variables to
      the annotate the type of the fixpoint, which doesn't abstract over the type
      parameters itself. *)
  Definition foldL {A B : Type} (f : A -> B -> A) : list B -> A -> A :=
    fix foldL (l : list B) (a0 : A) {struct l} : A :=
      match l with
      | [] => a0
      | b :: t => foldL t (f a0 b)
      end.

  Definition sum (xs : list nat) := foldL Nat.add xs 0.

  Definition harness (sum_func : string) : string :=
    "let main (st : unit * nat option) : operation list * (nat option)  = (([]: operation list), Some ( " ++ sum_func ++ "([1n;2n;3n])))".

  Time MetaCoq Run
       (t <- CameLIGO_extract_single
              []
              []
              TT_rename_ctors_default
              "let addN (n : nat) (m : nat) = n + m"
              (harness "sum")
              sum ;;
        tmDefinition "cameligo_sum" t).

    (** Extraction results in fully functional CameLIGO code *)
    Redirect "tests/extracted-code/cameligo-extract/FoldL.mligo"
    MetaCoq Run (tmMsg cameligo_sum).

  (** This definition is different from [foldL]. The type abstractions are part of the
      fixpoint, and not binded by lambdas. Therefore, the type parameters are not
      eliminated by optimisations. We test here another property, however, namely, how
      the annotation machinery handles polymophism when the node has a polymoprhic type. *)
  Fixpoint foldLAlt {A B : Type} (f : A -> B -> A) (l : list B) (a0 : A) : A :=
      match l with
      | [] => a0
      | b :: t => foldLAlt f t (f a0 b)
      end.

  Definition sumAlt (xs : list nat) := foldLAlt Nat.add xs 0.

    Time MetaCoq Run
       (t <- CameLIGO_extract_single
              []
              []
              TT_rename_ctors_default
              "let addN (n : nat) (m : nat) = n + m"
              (harness "sumAlt")
              sumAlt ;;
        tmDefinition "cameligo_sumAlt" t).

    (** Extraction results in fully functional CameLIGO code *)
    Redirect "tests/extracted-code/cameligo-extract/FoldLAlt.mligo"
    MetaCoq Run (tmMsg cameligo_sumAlt).

End FoldLeft.

Module SafeHead.
  (** This module shows how one can extract programs containing [False_rect] *)

  Open Scope list.
  Open Scope nat.

  (** We cannot make [safe_head] polymoprhic due to CameLIGO restrictions *)
  Program Definition safe_head (l : list nat) (non_empty : List.length l > 0) : nat :=
    match l as l' return l' = l -> nat  with
    | [] => (* this is an impossible case *)
      (* NOTE: we use [False_rect] to have more control over the extracted code. *)
      (* Leaving a hole for the whole branch potentially leads to polymoprhic *)
      (* definitions in the extracted code and type like [eq], since we would have to leave the whole goal branch transparent (use [Defined] instead of [Qed] ). *)
      (* In this case, one has to inspect the extracted code and inline such definitions *)
      fun _ => False_rect _ _
    | hd :: tl => fun _ => hd
    end eq_refl.
  Next Obligation.
    intros. subst. inversion non_empty.
  Qed.

  Program Definition head_of_list_2 (xs : list nat) := safe_head (0 :: 0 :: xs)  _.
  Next Obligation.
    intros. cbn. lia.
  Qed.

  (** We inline [False_rect] and [False_rec] to make sure that no polymoprhic definitions are left *)
  Definition safe_head_inline :=
    [<%% False_rect %%>; <%% False_rec %%>].

  Definition TT_consts := [ remap <%% @hd_error %%> "List.head_opt" ].
  Definition TT_ctors := [("O","0n")].

  Definition harness : string :=
    "let main (st : unit * nat option) : operation list * (nat option)  = (([]: operation list), Some (head_of_list_2 ([] : nat list)))".

    Time MetaCoq Run
         (t <- CameLIGO_extract_single
                safe_head_inline
                TT_consts
                (TT_ctors ++ TT_rename_ctors_default)
                ""
                harness
                head_of_list_2 ;;
    tmDefinition "cameligo_safe_head" t).

    (** Extraction results in fully functional CameLIGO code *)
    Redirect "tests/extracted-code/cameligo-extract/SafeHead.mligo"
    MetaCoq Run (tmMsg cameligo_safe_head).

End SafeHead.