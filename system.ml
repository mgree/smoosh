let parse_keqv s = 
  let eq = String.index s '=' in
  let k = String.sub s 0 eq in
  let v = String.sub s (eq+1) (String.length s - eq - 1) in
  (k,v)

let real_environment () : (string * string) list =
  let environ = Unix.environment () in
  Array.to_list (Array.map parse_keqv environ)

let real_getpwnam (nam : string) : string option =
  try Some ((Unix.getpwnam nam).pw_dir)
  with Not_found -> None

let real_fork_and_execve (cmd : string) (argv : string list) (environ : string list) : int =
  match Unix.fork () with
  | 0 -> 
     Unix.execve cmd (Array.of_list (cmd::argv)) (Array.of_list environ)
  | pid -> pid

let real_fork_and_call (f : 'a -> int) (v : 'a) : int =
  match Unix.fork () with
  | 0 -> 
     let status = f v in 
     let _ = Printf.eprintf "pid %d exiting\n" (Unix.getpid ()) in
     exit status
  | pid -> pid

let real_waitpid (pid : int) : int = 
  try match Unix.waitpid [] pid with
  | (_,Unix.WEXITED code) -> code
  | (_,Unix.WSIGNALED signal) -> 130 (* bash, dash behavior *)
  | (_,Unix.WSTOPPED signal) -> 146 (* bash, dash behavior *)
  with Unix.Unix_error(EINTR,_,_) -> 130

let real_exists (path : string) : bool = Sys.file_exists path

let real_isexec (path : string) : bool =
  try if Sys.file_exists path 
      then (Unix.access path [Unix.F_OK; Unix.X_OK]; true)
      else false
  with Unix.Unix_error(_,_,_) -> false

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

type open_flags = Unix.open_flag list

let to_flags = [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL]
let clobber_flags = [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC]
let from_flags = [Unix.O_RDONLY]
let fromto_flags = [Unix.O_RDWR; Unix.O_CREAT]
let append_flags = [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_APPEND]

let real_open (file:string) (flags:open_flags) : (string,int) Either.either =
  try Right (int_of_fd (Unix.openfile file flags 0o666))
  with Unix.Unix_error(e,_,_) -> Left (Unix.error_message e)

let real_close (fd:int) : unit =
  try Unix.close (fd_of_int fd)
  with Unix.Unix_error(_,_,_) -> ()

(* uninterruptable write, per dash *)
let rec xwrite (fd:Unix.file_descr) (buff : Bytes.t) : bool =
  let len = Bytes.length buff in
  try 
    let written = Unix.write fd buff 0 len in
    written = len
  with Unix.Unix_error(Unix.EINTR,_,_) -> xwrite fd buff (* just try again *)
     | Unix.Unix_error(_,_,_) -> false

let real_write_fd (fd:int) (s:string) : bool =
  let buff = Bytes.of_string s in
  xwrite (fd_of_int fd) buff

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

let real_pipe () : int * int =
  let (fd_read,fd_write) = Unix.pipe () in
  (int_of_fd fd_read, int_of_fd fd_write)

let real_openhere (s : string) : (string,int) Either.either =
  let buff = Bytes.of_string s in
  try 
    let (fd_read, fd_write) = Unix.pipe () in
    if Bytes.length buff <= 4096 (* from dash *)
    then 
      (* just write it, the pipe can hold it *)
      begin
        ignore (xwrite fd_write buff);
        Unix.close fd_write;
        Right (int_of_fd fd_read)
      end       
    else 
      (* heredoc is too big for the pipe, so spin up a process to do the writing *)
      match Unix.fork () with
      | 0 -> 
         begin
           Unix.close fd_read;
           (* ignore SIGINT, SIGQUIT, SIGHUP, SIGTSTP *)
           Sys.set_signal Sys.sigint Sys.Signal_ignore;
           Sys.set_signal Sys.sigquit Sys.Signal_ignore;
           Sys.set_signal Sys.sighup Sys.Signal_ignore;
           Sys.set_signal Sys.sigtstp Sys.Signal_ignore;
           (* SIGPIPE gets default handler... maybe we didn't need the whole heredoc? *)
           Sys.set_signal Sys.sigpipe Sys.Signal_default;
           ignore (xwrite fd_write buff);
           exit 0
         end
      | _pid -> 
         begin
           Unix.close fd_write;
           Right (int_of_fd fd_read)
         end
  with Unix.Unix_error(e,_,_) -> Left (Unix.error_message e)
               
