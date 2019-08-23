(* positional information *)

type t = Lexing.position * Lexing.position

let get_file_name : Lexing.position -> string =
    fun pos ->
    pos.Lexing.pos_fname

let get_line_num : Lexing.position -> int =
    fun pos ->
    pos.Lexing.pos_lnum

let get_line_pos : Lexing.position -> int =
    fun pos ->
    let cnum = pos.Lexing.pos_cnum in
    let bol = pos.Lexing.pos_bol in
    cnum - bol

let get_parser_pos : unit -> t = fun () ->
    (Parsing.symbol_start_pos (), Parsing.symbol_end_pos ())

let get_lexer_pos : Lexing.lexbuf -> t = fun lexbuf ->
    (Lexing.lexeme_start_p lexbuf, Lexing.lexeme_end_p lexbuf)

let compose : t -> t -> t = fun (ls, lt) (rs, rt) -> (ls, rt)

let string_of_file_name : Lexing.position -> string =
    fun pos ->
    let sf = get_file_name pos in
    if sf = "" then "Input "
    else "File \"" ^ sf ^ "\", "

let to_string : t -> string =
    fun (start_pos, end_pos) ->
    let sf = string_of_file_name start_pos in
    let sl = get_line_num start_pos in
    let sp = get_line_pos start_pos + 1 in
    let el = get_line_num end_pos in
    let ep = get_line_pos end_pos in
    let ssl = string_of_int sl in
    let ssp = string_of_int sp in
    let sep = string_of_int ep in
    if sl = el then
        if ep <= sp then sf ^ "line " ^ ssl ^ ", character " ^ sep
        else sf ^ "line " ^ ssl ^ ", characters " ^ ssp ^ "-" ^ sep
    else
        let sel = string_of_int el in
        sf ^ "from line " ^ ssl ^ ", character " ^ ssp ^
        " to line " ^ sel ^ ", character " ^ sep
