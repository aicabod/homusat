(* type check for argument formulas *)

module Env = Id.IdMap
module Delta = LTS.Delta
module States = LTS.States
module FmlMap = ACG.FmlMap
module Tau = Types.Tau
module Sigma = Types.Sigma
module Gamma = Types.Gamma
module Theta = Types.Theta
module Epsilon = Types.Epsilon

let memo = ref Epsilon.empty
let reset_memo = fun () -> memo := Epsilon.empty

(* check if the formula fml can be typed with tau *)
let rec is_typable = fun delta te fml tau ->
    Profile.check_time_out "model checking" !Flags.time_out;
    let tbl = Epsilon.find_default FmlMap.empty tau !memo in
    if FmlMap.mem fml tbl then FmlMap.find fml tbl
    else
        let ret = is_typable_without_memo delta te fml tau in
        let tbl = FmlMap.add fml ret tbl in
        memo := Epsilon.add tau tbl !memo;
        ret
and is_typable_without_memo = fun delta te fml tau ->
    match fml with
    | HFS.Or (xs) ->
        let f = fun delta te tau x -> is_typable delta te x tau in
        List.exists (f delta te tau) xs
    | HFS.And (xs) ->
        let f = fun delta te tau x -> is_typable delta te x tau in
        List.for_all (f delta te tau) xs
    | HFS.Box (a, x) ->
        let q = Types.codom tau in
        let f = fun delta te x p ->
            let tau = Tau.encode ([], p) in
            is_typable delta te x tau
        in
        let ps = Delta.find_default States.empty (q, a) delta in
        States.for_all (f delta te x) ps
    | HFS.Diamond (a, x) ->
        let q = Types.codom tau in
        let f = fun delta te x p ->
            let tau = Tau.encode ([], p) in
            is_typable delta te x tau
        in
        let ps = Delta.find_default States.empty (q, a) delta in
        States.exists (f delta te x) ps
    | HFS.App (x, ys) ->
        let f = fun tau n tc -> tau = (Types.drop tc n) in
        let tcs = Env.find_default Sigma.empty x te in
        let tcs = Sigma.filter (f tau (List.length ys)) tcs in
        Sigma.exists (is_typable_app delta te ys) tcs
and is_typable_app = fun delta te ys tau ->
    let f = fun delta te (y, sigma) ->
        Sigma.for_all (is_typable delta te y) sigma
    in
    let ys = Types.annot ys tau in
    List.for_all (f delta te) ys

(* return the set of types that fml can be typed under delta *)
let types = fun qs delta te fml ->
    match fml with
    | HFS.App (x, ys) ->
        let f = fun delta te x ys tau acc ->
            if is_typable_app delta te ys tau then
                let tau = Types.drop tau (List.length ys) in
                Sigma.add tau acc
            else acc
        in
        let tcs = Env.find_default Sigma.empty x te in
        Sigma.fold (f delta te x ys) tcs Sigma.empty
    | _ ->
        let f = fun delta te fml q acc ->
            let tau = Tau.encode ([], q) in
            if is_typable delta te fml tau then
                Sigma.add tau acc
            else acc
        in
        States.fold (f delta te fml) qs Sigma.empty

module EnvMap = X.Map.Make (struct
    type t = Sigma.t Env.t
    let compare : t -> t -> int = Env.compare Sigma.compare
end)

let hoge = ref FmlMap.empty
let reset_hoge = fun fml -> hoge := FmlMap.remove fml !hoge

let types = fun qs delta lhste rhste fml ->
    let te = Types.merge_gammas lhste rhste in
    types qs delta te fml
(*
    let fuga = FmlMap.find_default EnvMap.empty fml !hoge in
    if EnvMap.mem rhste fuga then
        EnvMap.find rhste fuga
    else
        let te = Types.merge_gammas lhste rhste in
        let ret = types qs delta te fml in
        let fuga = EnvMap.add rhste ret fuga in
        hoge := FmlMap.add fml fuga !hoge;
        ret
*)
