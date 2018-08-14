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
     Unix.execve cmd (Array.of_list argv) (Array.of_list environ)
  | pid -> pid

