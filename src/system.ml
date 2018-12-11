open Either

(* use the ExtUnix sub-library where calls that compile are implemented *)
module ExtUnix = ExtUnixSpecific

(* NB on Unix systems, the abstract type `file_descriptor` is just an int *)
let fd_of_int : int -> Unix.file_descr = Obj.magic
let int_of_fd : Unix.file_descr -> int = Obj.magic

let implode = Dash.implode
let explode = Dash.explode

let all_signals =
  [ Sys.sigabrt
  ; Sys.sigalrm
  ; Sys.sigfpe
  ; Sys.sighup
  ; Sys.sigill
  ; Sys.sigint
  ; Sys.sigkill
  ; Sys.sigpipe
  ; Sys.sigquit
  ; Sys.sigsegv
  ; Sys.sigterm
  ; Sys.sigusr1
  ; Sys.sigusr2
  ; Sys.sigchld
  ; Sys.sigcont
  ; Sys.sigstop
  ; Sys.sigtstp
  ; Sys.sigttin
  ; Sys.sigttou
  ; Sys.sigvtalrm
  ; Sys.sigprof
  ; Sys.sigbus
  ; Sys.sigpoll
  ; Sys.sigsys
  ; Sys.sigtrap
  ; Sys.sigurg
  ; Sys.sigxcpu
  ; Sys.sigxfsz]

(* for backpatching the real_eval function 
   takes a command to its exit code
 *)
type real_os_state = unit Os.os_state
let shell_state : real_os_state option ref = ref None

let gotsigchld = ref false
let sigblockall () = ignore (Unix.sigprocmask Unix.SIG_BLOCK all_signals)
let sigunblockall () = ignore (Unix.sigprocmask Unix.SIG_UNBLOCK all_signals)

let real_sync_state os =
  shell_state := Some os;
  os

let real_eval : (real_os_state -> Smoosh_prelude.stmt -> int) ref =
  ref (fun _ _ -> failwith "real_eval knot is untied")

let real_eval_string : (real_os_state -> string -> int) ref = 
  ref (fun _ -> failwith "real_eval_string knot is untied")

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

let rec real_execve (cmd : string) (argv : string list) (environ : string list) (binsh : bool) 
        : 'a =
  let env = Array.of_list environ in
  try Unix.execve cmd (Array.of_list (cmd::argv)) env
  with 
    | Unix.Unix_error(Unix.EINTR,_,_) -> real_execve cmd argv environ binsh
    | Unix.Unix_error(Unix.ENOEXEC,_,_) as err ->
       if binsh && cmd <> "/bin/sh"
       then 
         (* tell execve what our command name is, once to pass it to the shell *)
         Unix.execve "/bin/sh" (Array.of_list ("/bin/sh"::cmd::argv)) env
       else raise err

let ttyfd : Unix.file_descr option ref = ref None
let initialpgrp = ref (-1)

let set_initialpgrp () =
  match !ttyfd with
  | None -> initialpgrp := -1
  | Some fd ->
     try initialpgrp := ExtUnix.tcgetpgrp fd
     with Unix.Unix_error(_,_,_) ->
           begin
             ttyfd := None;
             initialpgrp := -1
           end

let open_ttyfd () =
  match !ttyfd with
  | None ->
     ttyfd := 
       (try 
          (* FIXME 2018-10-24 tty path configurable *)
          Some (Unix.openfile "/dev/tty" [Unix.O_RDWR] 0o666)
        with Unix.Unix_error(_,_,_) -> begin
            try if Unix.isatty Unix.stdin
                then Some Unix.stdin
                else if Unix.isatty Unix.stdout
                then Some Unix.stdout
                else if Unix.isatty Unix.stderr
                then Some Unix.stderr
                else None
            with Unix.Unix_error(_,_,_) -> None
          end)
  | Some _ -> ()

let close_ttyfd () =
  match !ttyfd with
  | None -> ()
  | Some fd -> 
     begin 
       ttyfd := None;
       Unix.close fd
     end

let real_getpgrp () = ExtUnix.getpgid 0

let xtcsetpgrp pgid : bool =
  match !ttyfd with
  | None -> false
  | Some fd ->
     try ExtUnix.tcsetpgrp fd pgid; true
     with Unix.Unix_error(_e,_,_) ->
       (* disabling warning because we're overdoing this *)
       (* Printf.eprintf "Cannot set tty process group (%s)\n" (Unix.error_message e) *)
       false

let xsetpgid pid pgrp =
  if pgrp >= 0
  then try ExtUnix.setpgid pid pgrp
       with Unix.Unix_error(Unix.EINVAL,_,_) -> ()
          
let real_enable_jobcontrol rootpid =
  open_ttyfd ();
  set_initialpgrp ();
  if !initialpgrp <> -1
  then 
    begin
      Sys.set_signal Sys.sigttou Sys.Signal_ignore;
      Sys.set_signal Sys.sigttin Sys.Signal_ignore;
      Sys.set_signal Sys.sigtstp Sys.Signal_ignore;
      xsetpgid 0 rootpid;
      ignore (xtcsetpgrp rootpid)
    end

let real_disable_jobcontrol () =
  ignore (xtcsetpgrp !initialpgrp);
  xsetpgid 0 !initialpgrp;
  Sys.set_signal Sys.sigttou Sys.Signal_default;
  Sys.set_signal Sys.sigttin Sys.Signal_default;
  Sys.set_signal Sys.sigtstp Sys.Signal_default;   
  close_ttyfd ()

let real_exit (code : int) = 
  real_disable_jobcontrol ();
  exit code

let real_fork_and_eval 
      (handlers : int list) 
      (os : 'a) (stmt : Smoosh_prelude.stmt) 
      (bg : bool) (pgid : int option) (outermost : bool) (jc : bool) (interactive : bool) : int =
  let pgrp pid =
       match pgid with
       | None -> pid
       | Some pgid -> pgid
  in
  (* TODO 2018-10-01 use vfork? it's not even in ExtUnix :( *)
  sigblockall ();
  match Unix.fork () with
  | 0 -> 
     List.iter 
       (fun signal -> if signal <> 0 then Sys.set_signal signal Signal_ignore) 
       handlers;
     (* more or less following dash's forkchild in jobs.c:847-907 *)
     if outermost && jc
     then begin
         Sys.set_signal Sys.sigtstp Signal_ignore;
         Sys.set_signal Sys.sigttou Signal_ignore;
         Sys.set_signal Sys.sigttin Signal_ignore;
         let pid = Unix.getpid () in
         xsetpgid 0 (pgrp pid);
         if not bg 
         then
           ignore (xtcsetpgrp (pgrp pid))
       end
     else if bg
     then 
       begin
         Sys.set_signal Sys.sigint Signal_ignore;
         Sys.set_signal Sys.sigquit Signal_ignore;
       end;
     if outermost && interactive
     then
       begin
         Sys.set_signal Sys.sigterm Signal_default;
         if not bg
         then
           begin
             Sys.set_signal Sys.sigint Signal_default;
             Sys.set_signal Sys.sigquit Signal_default;
           end;
       end;
     (* save state for handlers---will be process-local *)
     shell_state := Some os;
     sigunblockall ();
     let status = !real_eval os stmt in 
     (* TODO restore the terminal? *)
     real_exit status
  | pid -> 
     sigunblockall (); 
     if jc
     then 
       xsetpgid pid (pgrp pid);
     pid

let rec real_waitpid (rootpid : int) (pid : int) (jc : bool) : int = 
  let code =
    try match Unix.waitpid [] pid with
        | (_,Unix.WEXITED code) -> code
        | (_,Unix.WSIGNALED signal) -> 128 + signal (* bash, dash behavior *)
        | (_,Unix.WSTOPPED signal) -> 128 + signal (* bash, dash behavior *)
    with Unix.Unix_error(Unix.EINTR,_,_) -> real_waitpid rootpid pid jc
       | Unix.Unix_error(Unix.ECHILD,_,_) -> gotsigchld := true; 0
  in
  (* FIXME 2018-10-24 we may need to interrupt ourselves when code=130 
     see jobs.c:1032
   *)
  if jc
  then ignore (xtcsetpgrp rootpid);
  code

let real_wait_child (jc : bool) : (int * Unix.process_status) option =
  let flags = if jc then [Unix.WNOHANG; Unix.WUNTRACED] else [Unix.WNOHANG] in
  try 
    match Unix.waitpid flags (-1) with
    | (0, _) -> None (* running/no update *)
    | (pid, status) -> Some (pid, status)
  with Unix.Unix_error(Unix.ECHILD,_,_) -> None

let show_time time =
  let mins = time /. 60.0 in
  let secs = mod_float time 60.0 in
  Printf.sprintf "%dm%fs" (int_of_float mins) secs

let real_times () : string * string * string * string =
  let ptimes = Unix.times () in
  (show_time ptimes.tms_utime,
   show_time ptimes.tms_stime,
   show_time ptimes.tms_cutime,
   show_time ptimes.tms_cstime)

let real_get_umask () : int =
  (* TODO 2018-09-19 INTOFF/INTON *)
  let mask = Unix.umask 0 in
  ignore (Unix.umask mask);
  mask

let real_set_umask (mask : int) : unit =
  ignore (Unix.umask mask)

let real_file_exists (path : string) : bool = Sys.file_exists path

let real_file_perms (path : string) : int option =
  try Some (Unix.stat path).st_perm
  with Unix.Unix_error(_,_,_) -> None

let real_file_size (path : string) : int option =
  try Some (Unix.stat path).st_size
  with Unix.Unix_error(_,_,_) -> None

let real_file_perms (path : string) : int option =
  try Some (Unix.stat path).st_perm
  with Unix.Unix_error(_,_,_) -> None

let real_is_readable (path : string) : bool =
  try Unix.access path [Unix.F_OK; Unix.R_OK]; true
  with Unix.Unix_error(_,_,_) -> false

let real_is_writeable (path : string) : bool =
  try Unix.access path [Unix.F_OK; Unix.R_OK]; true
  with Unix.Unix_error(_,_,_) -> false

let real_is_executable (path : string) : bool =
  try Unix.access path [Unix.F_OK; Unix.X_OK]; true
  with Unix.Unix_error(_,_,_) -> false

let real_file_type (path : string) : Unix.file_kind option =
  try Some (Unix.lstat path).st_kind
  with Unix.Unix_error(_,_,_) -> None

let real_file_type_follow (path : string) : Unix.file_kind option =
  try Some (Unix.stat path).st_kind
  with Unix.Unix_error(_,_,_) -> None
                               
let real_isdir (path : string) : bool = 
  Sys.file_exists path && Sys.is_directory path


let real_readdir (path : string) : (string * bool) list =
  let contents = Sys.readdir path in
  let dir_info file = (file, real_isdir (Filename.concat path file)) in
  Array.to_list (Array.map dir_info contents)

let real_chdir (path : string) : string option =
  try if real_isdir path 
      then (Unix.chdir path; None)
      else Some ("no such directory " ^ path)
  with Unix.Unix_error(e,_,_) -> Some (Unix.error_message e)

let real_is_tty (fd : int) = Unix.isatty (fd_of_int fd)

type open_flags = Unix.open_flag list

let to_flags = [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL]
let clobber_flags = [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC]
let from_flags = [Unix.O_RDONLY]
let fromto_flags = [Unix.O_RDWR; Unix.O_CREAT]
let append_flags = [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_APPEND]

let real_open (file:string) (flags:open_flags) : (string,int) either =
  try Right (int_of_fd (Unix.openfile file flags 0o666))
  with 
  | Unix.Unix_error(Unix.EEXIST,_,_) -> Left ("cannot create " ^ file ^ ": file exists")
  | Unix.Unix_error(e,_,_) -> Left (Unix.error_message e)

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

let real_read_all_fd (fd:int) : string option =
  let rec drain buff ofs =
    let read = 
      try Unix.read (fd_of_int fd) buff ofs (Bytes.length buff - ofs) 
      with Unix.Unix_error(Unix.EPIPE,_,_) -> 0
         | Unix.Unix_error(Unix.EBADF,_,_) -> 0
         | Unix.Unix_error(Unix.EINTR,_,_) -> 0
    in
    if read = 0
    then Some (Bytes.sub_string buff 0 ofs)
    else if read > 0
    then 
      (* TODO 2018-11-12 this grows too much *)
      let ofs' = ofs + read in
      let buff' = 
        (* double the buffer as necessary *)
        if ofs' >= Bytes.length buff 
        then Bytes.extend buff 0 (Bytes.length buff)
        else buff
      in
      drain buff' ofs'
    else None
  in
  drain (Bytes.make 1024 (Char.chr 0)) 0

(* TODO 2018-10-11 distinguish error and EOF? *)
let real_read_char_fd (fd:int) : (string,char option) either =
  let buff = Bytes.make 1 (Char.chr 0) in
  try 
    match Unix.read (fd_of_int fd) buff 0 1 with
    | 0 -> Right None
    | 1 -> Right (Some (Bytes.get buff 0))
    | _ -> Left ("couldn't read " ^ string_of_int fd)
  with Unix.Unix_error(Unix.EPIPE,_,_) -> Left "broken pipe"
     | Unix.Unix_error(Unix.EBADF,_,_) -> Left "no such fd"
     | Unix.Unix_error(Unix.EINTR,_,_) -> Left "interrupted"

let real_read_line_fd backslash_escapes (fd:int) 
    : (string, string * bool (* eof? *)) either =
  let rec loop cs =
    match real_read_char_fd fd with
    | Left msg -> Left msg
    | Right None -> Right (cs, true)
    | Right (Some '\n') -> Right (cs, false)
    | Right (Some '\\') when backslash_escapes ->
       begin match real_read_char_fd fd with
       | Left msg -> Left msg
       | Right None -> Right ('\\'::cs, true)
       | Right (Some '\n') -> loop cs
       | Right (Some c) -> loop (c::cs)
       end
    | Right (Some c) -> loop (c::cs)
  in
  match loop [] with
  | Left msg -> Left msg
  | Right (cs, eof) -> Right (implode (List.rev cs), eof)

let real_savefd (fd:int) : (string,int) either =
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

let real_openhere (s : string) : (string,int) either =
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

let current_traps : (int * string) list ref = ref []

let handler signal =
  if signal = Sys.sigchld
  then 
    (* TODO 2018-10-29 handle set -o notify properly *)
    gotsigchld := true;
  match List.assoc_opt signal !current_traps with
  | None -> ()
  | Some cmd -> 
     match !shell_state with
     | None -> failwith "uninitialized shell_state in handler"
     | Some os -> ignore (!real_eval_string os cmd)

let real_handle_signal signal action =
  let old_traps = List.remove_assoc signal !current_traps in
  let (new_traps,handler) =
    match action with
    | None     -> ([],             Sys.Signal_default)
    | Some  "" -> ([(signal,"")],  Sys.Signal_ignore)
    | Some cmd -> ([(signal,cmd)], Sys.Signal_handle handler)
  in
  current_traps := new_traps @ old_traps;
  if signal <> 0
  then Sys.set_signal signal handler

let real_signal_pid signal pid as_pg =
  try Unix.kill (if as_pg then -pid else pid) signal; true
  with Unix.Unix_error(_) -> false
