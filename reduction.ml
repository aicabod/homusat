(* reduce applications of non-recursive functions *)
(* currently applied to the functions called only once *)

module LHS = Id.IdMap
module IdSet = Id.IdSet

(* replace formal arguments with applied formulas *)
let rec subst = fun sub fml ->
    Profile.check_time_out "model checking" !Flags.time_out;
    match fml with
    | HFS.Or (xs) ->
        let xs = List.rev (List.rev_map (subst sub) xs) in
        HFS.Or (xs)
    | HFS.And (xs) ->
        let xs = List.rev (List.rev_map (subst sub) xs) in
        HFS.And (xs)
    | HFS.Box (a, x) ->
        let x = subst sub x in
        HFS.Box (a, x)
    | HFS.Diamond (a, x) ->
        let x = subst sub x in
        HFS.Diamond (a, x)
    | HFS.App (x, ys) ->
        let ys = List.rev (List.rev_map (subst sub) ys) in
        if LHS.mem x sub then
            let fml = LHS.find x sub in
            match fml with
            | HFS.App (x, zs) ->
                let ys = List.rev_append (List.rev zs) ys in
                HFS.App (x, ys)
            | _ -> (* (assert (ys = [])); *) fml
        else HFS.App (x, ys)

(* reduce applications of non-recursive functions *)
let rec reduce_fml = fun nonrecs fml ->
    Profile.check_time_out "model checking" !Flags.time_out;
    match fml with
    | HFS.Or (xs) ->
        let xs = List.rev (List.rev_map (reduce_fml nonrecs) xs) in
        HFS.Or (xs)
    | HFS.And (xs) ->
        let xs = List.rev (List.rev_map (reduce_fml nonrecs) xs) in
        HFS.And (xs)
    | HFS.Box (a, x) ->
        let x = reduce_fml nonrecs x in
        HFS.Box (a, x)
    | HFS.Diamond (a, x) ->
        let x = reduce_fml nonrecs x in
        HFS.Diamond (a, x)
    | HFS.App (x, ys) ->
        if LHS.mem x nonrecs then
            let (args, fml) = LHS.find x nonrecs in
            if List.length args = List.length ys then (* non-partial *)
                let f = fun acc x y -> LHS.add x y acc in
                let sub = List.fold_left2 f LHS.empty args ys in
                let fml = subst sub fml in
                reduce_fml nonrecs fml
            else (* partial applications are ignored *)
                let rys = List.rev_map (reduce_fml nonrecs) ys in
                let ys = List.rev rys in
                HFS.App (x, ys)
        else
            let ys = List.rev (List.rev_map (reduce_fml nonrecs) ys) in
            HFS.App (x, ys)

let reduce_func = fun nonrecs func ->
    let (fp, x, sort, args, fml) = func in
    if LHS.mem x nonrecs then
        let (_, fml) = LHS.find x nonrecs in
        (fp, x, sort, args, fml)
    else
        let fml = reduce_fml nonrecs fml in
        (fp, x, sort, args, fml)

(* non-recursive function \mapsto (args, body) *)
let generate_nonrec_map = fun funcs ->
    let f = fun fmap acc x ->
        let (args, fml) = LHS.find x fmap in
        let fml = reduce_fml acc fml in
        LHS.add x (args, fml) acc
    in
    let fmap = Preproc.generate_fmap funcs in
    (* let nonrecs = Preproc.generate_nonrecs funcs in *)
    let nonrecs = Preproc.generate_onces funcs in
    List.fold_left (f fmap) LHS.empty (List.rev nonrecs)

let reduce = fun funcs ->
    let funcs = Preproc.remove_unreachables funcs in
    let nonrecs = generate_nonrec_map funcs in
    let funcs = List.rev (List.rev_map (reduce_func nonrecs) funcs) in
    Preproc.remove_unreachables funcs