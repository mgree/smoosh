let real_getpwnam (nam : string) : string option =
  try Some ((Unix.getpwnam nam).pw_dir)
  with Not_found -> None

let real_fork_and_execve (cmd : string) (argv : string list) (environ : string list) : int =
  match Unix.fork () with
  | 0 -> 
     (* TODO 2018-08-14 take and manipulate fds; need to update os.lem accordingly when done *)
     Unix.execve cmd (Array.of_list (cmd::argv)) (Array.of_list environ)
  | pid -> pid

let real_fork_and_call (f : 'a -> 'b) (v : 'a) : int =
  match Unix.fork () with
  | 0 -> 
     (* TODO 2018-08-14 take and manipulate fds; need to update os.lem accordingly when done *)
     let status = f v in 
     exit status
  | pid -> pid

let real_waitpid (pid : int) : int = 
  try match Unix.waitpid [] pid with
  | (_,Unix.WEXITED code) -> code
  | (_,Unix.WSIGNALED signal) -> 130 (* bash, dash behavior *)
  | (_,Unix.WSTOPPED signal) -> 146 (* bash, dash behavior *)
  with Unix.Unix_error(EINTR,_,_) -> 130

let real_exists (path : string) : bool = Sys.file_exists path

let real_isdir (path : string) : bool = Sys.file_exists path && Sys.is_directory path

let real_readdir (path : string) : (string * bool) list =
  let contents = Sys.readdir path in
  let dir_info file = (file, real_isdir (Filename.concat path file)) in
  Array.to_list (Array.map dir_info contents)

let real_chdir (path : string) : string option =
  try if real_isdir path 
      then (Unix.chdir path; None)
      else Some ("no such directory " ^ path)
  with Unix.Unix_error(e,_,_) -> Some (Unix.error_message e)

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

let real_savefd (fd:int) : (string,int) Either.either =
  (* dash is careful to get a new fd>10 by using an explicit fcntl call.
     we don't have access to fcntl in Unix.cmx;
     ocaml-unix-fcntl doesn't seeem to offer the fd functions
     so: we'll just take the fd that we get. it'll be fresh, in any case
   *)
  try
    let newfd = Unix.dup ~cloexec:true (fd_of_int fd) in
    Right (int_of_fd newfd)
  with Unix.Unix_error(e,_,_) -> Left (Unix.error_message e)

let real_dup2 (orig_fd:int) (tgt_fd:int) : string option =
  try Unix.dup2 (fd_of_int orig_fd) (fd_of_int tgt_fd); None
  with Unix.Unix_error(e,_,_) -> Some (Unix.error_message e)

let real_close (fd:int) : unit =
  try Unix.close (fd_of_int fd)
  with Unix.Unix_error(_,_,_) -> ()

let real_pipe () : (string,int * int) Either.either =
  try let (fd_read,fd_write) = Unix.pipe () in
      Right (int_of_fd fd_read, int_of_fd fd_write)
  with Unix.Unix_error(e,_,_) -> Left (Unix.error_message e)
