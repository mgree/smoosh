open Fsh

let add_literal_env_string k v s0 = set_param k (Fsh.stringToSymbolicString v) s0

let os_var_x_null:ty_os_state= add_literal_env_string "x" "" os_empty
let os_var_x_set:ty_os_state = add_literal_env_string "x" "bar" os_empty
let os_var_x_set_three:ty_os_state= add_literal_env_string "x" "\"this is three\"" os_empty

let os_var_x_five:ty_os_state= add_literal_env_string "x" "5" os_empty

let os_ifs_spaceandcomma:ty_os_state= add_literal_env_string "IFS" " ," os_empty
let os_ifs_comma:ty_os_state= add_literal_env_string "IFS" "," os_empty

(***********************************************************************)
(* FILESYSTEM SCAFFOLDING **********************************************)
(***********************************************************************)

(* some worrying coercions we need in order to actually build an interesting filesystem *)
type fs_mut = {
  mutable parent: fs option;
  mutable contents: (string, file) Pmap.map
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
  let file = { parent = None; contents = Pmap.empty compare } in
  (* install it in the parent directory *)
  parent_dir.contents <- Pmap.add name (Dir (freeze file)) parent_dir.contents;
  (* set the parent link *)
  file.parent <- Some (freeze parent_dir);
  file

let set_fs (fs:fs_mut) (st:ty_os_state) : ty_os_state = 
  let root = freeze fs in
  { st with fs_root = root; sh = { st.sh with cwd = root } }

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
 *     user/
 *       x
 *       y
 *     useful
 *   b/
 *     user/
 *       z
 *   c/
 *      foo
 *)
let fs_complicated : fs_mut =
  let fs = fresh (thaw fs_empty) in
  let a_file = new_dir "a" fs in
  let b_file = new_dir "b" fs in
  let c_file = new_dir "c" fs in
  let a_use_file = new_dir "use" a_file in
  let a_user_file = new_dir "user" a_file in
  let b_user_file = new_dir "user" b_file in
  (* /a/*/* files *)
  new_file "x" a_use_file;
  new_file "x" a_user_file;
  new_file "y" a_user_file;
  new_file "useful" a_file;
  (* /b/*/* files *)
  new_file "z" b_user_file;
  (* /c/* files *)
  new_file "foo" c_file;
  fs

let os_complicated_fs = set_fs fs_complicated os_empty
