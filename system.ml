let real_getpwnam (nam : string) : string option =
  try Some ((Unix.getpwnam nam).pw_dir)
  with Not_found -> None

let real_readdir (path : string) : (string * bool) list =
  let contents = Sys.readdir path in
  let dir_info file = (file, Sys.is_directory (Filename.concat path file)) in
  Array.to_list (Array.map dir_info contents)

let real_fork_and_execve 
      (cmd : string) (argv : string list) 
      (environ : string list) : int =
  match Unix.fork () with
  | 0 -> 
     (* TODO 2018-08-14 take and manipulate fds; need to update os.lem accordingly when done *)
     Unix.execve cmd (Array.of_list (cmd::argv)) (Array.of_list environ)
  | pid ->   
     Printf.eprintf "%s %s" cmd (List.fold_right (fun arg s -> arg ^ " " ^ s) argv "");
     pid

let real_waitpid (pid : int) : int = 
  try match Unix.waitpid [] pid with
  | (_,Unix.WEXITED code) -> code
  | (_,Unix.WSIGNALED signal) -> 130 (* bash, dash behavior *)
  | (_,Unix.WSTOPPED signal) -> 146 (* bash, dash behavior *)
  with Unix.Unix_error(EINTR,_,_) -> 130

(* NB on Unix systems, the abstract type `file_descriptor` is just an int *)
let fd_of_int : int -> Unix.file_descr = Obj.magic
let int_of_fd : Unix.file_descr -> int = Obj.magic

let real_write_fd (fd:int) (s:string) : bool =
  let buff = Bytes.of_string s in
  let len = Bytes.length buff in
  let written = Unix.write (fd_of_int fd) buff 0 len in
  written = len

let real_read_fd (fd:int) : string option =
  (* allocate each time... may not be necessary with OCaml's model of shared memory *)
  let buff = Bytes.make 1024 (Char.chr 0) in
  let read = Unix.read (fd_of_int fd) buff 0 1024 in
  if read = 0
  then Some ""
  else if read > 0
  then Some (Bytes.sub_string buff 0 read)
  else None
