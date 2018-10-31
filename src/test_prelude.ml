open Smoosh
open Os_symbolic
   
(***********************************************************************)
(* TEST SCAFFOLDING ****************************************************)
(***********************************************************************)

(* test_name expected got *)
type 'a result = Ok | Err of 'a err
and 'a err = { msg : string;  expected : 'a; got : 'a }

let checker (test_fn : 'a -> 'b) (equal : 'b -> 'c -> bool)
            ((test_name, input, expected_out) : string * 'a * 'b) : 'b result =
  let out = test_fn input in
  if equal out expected_out
  then Ok
  else Err {msg = test_name; expected = expected_out; got = out}

let test_part name checker stringOfExpected tests count failed =
  List.iter
    (fun t ->
      match checker t with
      | Ok -> incr count
      | Err e ->
         Printf.printf "%s test '%s' failed: expected '%s' got '%s'\n"
                name e.msg (stringOfExpected e.expected) (stringOfExpected e.got);
         incr count; incr failed)
    tests

(***********************************************************************)
(* OS UTILITY FUNCTIONS ************************************************)
(***********************************************************************)

let add_literal_env_string k v s0 = internal_set_param k (symbolic_string_of_string v) s0
                                  
let os_var_x_null : symbolic os_state = add_literal_env_string "x" "" os_empty
let os_var_x_set : symbolic os_state = add_literal_env_string "x" "bar" os_empty
let os_var_x_set_three : symbolic os_state = add_literal_env_string "x" "\"this is three\"" os_empty

let os_var_x_five : symbolic os_state = add_literal_env_string "x" "5" os_empty

let os_ifs_spaceandcomma : symbolic os_state = add_literal_env_string "IFS" " ," os_empty
let os_ifs_comma : symbolic os_state = add_literal_env_string "IFS" "," os_empty

(***********************************************************************)
(* OCAML UTILITY FUNCTIONS *********************************************)
(***********************************************************************)

let show_list set =
  "[" ^ concat "," set ^ "]"  
                            
(***********************************************************************)
(* FILESYSTEM SCAFFOLDING **********************************************)
(***********************************************************************)

(* some worrying coercions we need in order to actually build an interesting filesystem *)
type fs_mut = {
  mutable parent: fs option;
  mutable contents: (string, symbolic_fs file) Pmap.map
  }

let freeze (fs : fs_mut) : fs = Obj.magic fs
let thaw (fs : fs) : fs_mut = Obj.magic fs
let fresh (fs : fs_mut) : fs_mut = 
  { parent = fs.parent;
    contents = Pmap.map (fun x -> x) fs.contents }

let new_file (name:string) (parent_dir:fs_mut) : unit =
  parent_dir.contents <- Pmap.add name File parent_dir.contents

let new_dir (name:string) (parent_dir:fs_mut) : fs_mut = 
  (* create the file *)
  let dir = { parent = None; contents = Pmap.empty compare } in
  (* install it in the parent directory *)
  parent_dir.contents <- Pmap.add name (Dir (freeze dir)) parent_dir.contents;
  (* set the parent link *)
  dir.parent <- Some (freeze parent_dir);
  dir

let set_fs (fs:fs_mut) (st : symbolic os_state) : symbolic os_state = 
  let root = freeze fs in
  { st with symbolic = { st.symbolic with fs_root = root }; sh = { st.sh with cwd = "/" } }

(* File system scaffolding *)
let fs_simple : fs_mut = 
  let fs = fresh (thaw fs_empty) in
  new_file "a" fs;
  fs

let os_simple_fs = set_fs fs_simple os_empty

(* Sample fs state
 * /
 *   a/
 *     use/
 *       x
 *     useful
 *     user/
 *       x
 *       y
 *   b/
 *     user/
 *       z
 *   c/
 *      .foo
 *      .bar/
 *        z
 *)
let fs_complicated : fs_mut =
  let fs = fresh (thaw fs_empty) in
  let a_file = new_dir "a" fs in
  let b_file = new_dir "b" fs in
  let c_file = new_dir "c" fs in
  let a_use_file = new_dir "use" a_file in
  let a_user_file = new_dir "user" a_file in
  let b_user_file = new_dir "user" b_file in
  let c_dotbar_file = new_dir ".bar" c_file in
  (* /a/*/* files *)
  new_file "x" a_use_file;
  new_file "x" a_user_file;
  new_file "y" a_user_file;
  new_file "useful" a_file;
  (* /b/*/* files *)
  new_file "z" b_user_file;
  (* /c/* files *)
  new_file ".foo" c_file;
  new_file "z" c_dotbar_file;
  fs

let os_complicated_fs = set_fs fs_complicated os_empty

let os_complicated_fs_in_a = 
  { os_complicated_fs with 
    sh = { os_complicated_fs.sh with cwd = "/a" } }
