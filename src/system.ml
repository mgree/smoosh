open Either

(* use the ExtUnix sub-library where calls that compile are implemented *)
module ExtUnix = ExtUnixSpecific

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

let pending_signals = ref []
let gotsigchld = ref false (* TODO 2018-12-14 for set -o notify *)
let sigblockall () = ignore (Unix.sigprocmask Unix.SIG_BLOCK all_signals)
let sigunblockall () = ignore (Unix.sigprocmask Unix.SIG_UNBLOCK all_signals)

let real_pending_signal () =
  match !pending_signals with
  | [] -> None
  | signal::rest ->
     begin
       pending_signals := rest;
       Some signal
     end

(* TODO 2018-12-14 dash has a different strategy for ordering signal
   handling.

   But: "If multiple signals are pending for the shell for which there
   are associated trap actions, the order of execution of trap actions
   is unspecified."  *)
let add_pending_signal ocaml_signal =
  begin
    if ocaml_signal = Sys.sigchld
    then
      (* TODO 2018-10-29 handle set -o notify properly *)
      gotsigchld := true
  end;
  try 
    let smoosh_signal = Signal.signal_of_ocaml_signal ocaml_signal in
    pending_signals := 
      smoosh_signal :: 
        (List.filter (fun s -> s <> smoosh_signal) !pending_signals)
  with _ -> 
    (* in case signal_of_ocaml_signal fails. this shouldn't happen,
       because we'll only install handlers for signals we know about.
       but: safety first! *)
    () 

(* for backpatching the real_eval function 
   takes a command to its exit code
 *)
type real_os_state = unit Os.os_state

let real_eval : (real_os_state -> Smoosh_prelude.stmt -> int) ref =
  ref (fun _ _ -> failwith "real_eval knot is untied")

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

let rec real_execve (cmd : string) (argv0 : string) (argv : string list) (environ : string list) (binsh : bool) 
        : 'a =
  let env = Array.of_list environ in
  try Unix.execve cmd (Array.of_list (argv0::argv)) env
  with 
    | Unix.Unix_error(Unix.EINTR,_,_) -> real_execve cmd argv0 argv environ binsh
    | Unix.Unix_error(Unix.ENOENT,_,_) ->
       begin
         Printf.eprintf "exec: %s: not found\n%!" cmd;
         exit 127
       end
    | Unix.Unix_error(Unix.ENOEXEC,_,_) as err ->
       if binsh && cmd <> "/bin/sh"
       then 
         (* tell execve what our command name is, once to pass it to the shell *)
         Unix.execve "/bin/sh" (Array.of_list ("/bin/sh"::cmd::argv)) env
       else
         begin
           Printf.eprintf "exec: %s: Permission denied" cmd;
           exit 127
         end
    | Unix.Unix_error(Unix.EACCES,_,_) ->
       begin
         Printf.eprintf "exec: %s: Permission denied" cmd;
         exit 126
       end      

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

let rec real_close (fd:int) : unit =
  try Unix.close (ExtUnix.file_descr_of_int fd)
  with Unix.Unix_error(Unix.EINTR,_,_) -> real_close fd
     | Unix.Unix_error(_,_,_) -> ()

let renumber ?cloexec:(ce=true) fd =
  let orig = ExtUnix.int_of_file_descr fd in
  let newfd = Dash.freshfd_ge10 orig in
  if newfd >= 0
  then begin
      real_close orig;
      if not ce
      then Unix.clear_close_on_exec (ExtUnix.file_descr_of_int newfd);
      newfd      
    end
  else failwith "out of file descriptors"
          
let rec xopenfile file flags mode =
  try 
    let fd = Unix.openfile file flags mode in
    try Right (renumber fd)
    with Failure msg -> Left msg
  with Unix.Unix_error(EINTR,_,_) -> xopenfile file flags mode
     | Unix.Unix_error(e,_,_) -> Left (Unix.error_message e)
          
let open_ttyfd () =
  match !ttyfd with
  | None ->
     ttyfd := 
       (try 
          (* FIXME 2018-10-24 tty path configurable *)
          let mfd = xopenfile "/dev/tty" [Unix.O_RDWR] 0o666 in
          match mfd with
          | Left err -> failwith err
          | Right fd -> Some (ExtUnix.file_descr_of_int fd)
        with _ -> begin
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
       real_close (ExtUnix.int_of_file_descr fd)
     end

let real_getpgrp () = ExtUnix.getpgid 0

let xtcsetpgrp pgid : bool =
  match !ttyfd with
  | None -> false
  | Some fd ->
     try ExtUnix.tcsetpgrp fd pgid; true
     with Unix.Unix_error(e,_,_) ->
       (* disabling warning because we're overdoing this *)
       Printf.eprintf "Cannot set tty process group to %d in %d (%s)\n" pgid (Unix.getpid ()) (Unix.error_message e); 
       false

let xsetpgid pid pgrp =
  if pgrp >= 0
  then try ExtUnix.setpgid pid pgrp
       with Unix.Unix_error(Unix.EINVAL,_,_) -> ()
          | Unix.Unix_error(Unix.EPERM,_,_) -> () (* must not be a tty... *)
          
let real_enable_jobcontrol rootpid =
  open_ttyfd ();
  let give_up msg = 
    initialpgrp := -1;
    close_ttyfd ();
    (* Printf.eprintf "set -m: %s; job control off\n%!" msg *) 
    (* TODO 2019-05-10 let people know that set -m didn't work *)
    ()
  in
  match !ttyfd with
  | Some tty ->
     let pgrp = real_getpgrp () in
     let rec foreground () =
       try let fg_pgrp = ExtUnix.tcgetpgrp tty in
           if fg_pgrp = pgrp
           then () (* okay, we're in the foreground *)
           else if fg_pgrp = -1
           then failwith "NOFG"
           else
             begin 
               Unix.kill 0 Sys.sigttin; 
               foreground() 
             end
       with Unix.Unix_error(e,_,_) -> give_up ("tcgetprgp: " ^ Unix.error_message e)
          | Failure("NOFG") -> give_up "couldn't take foreground"
     in
     foreground ();
     Sys.set_signal Sys.sigttou Sys.Signal_ignore;
     Sys.set_signal Sys.sigttin Sys.Signal_ignore;
     Sys.set_signal Sys.sigtstp Sys.Signal_ignore;
     initialpgrp := pgrp;
     xsetpgid 0 rootpid;
     ignore (xtcsetpgrp rootpid)
  | None -> give_up "can't access tty"

let real_disable_jobcontrol () =
  match !ttyfd with
  | None -> ()
  | Some _ ->
     begin
       ignore (xtcsetpgrp !initialpgrp);
       xsetpgid 0 !initialpgrp;
       Sys.set_signal Sys.sigttou Sys.Signal_default;
       Sys.set_signal Sys.sigttin Sys.Signal_default;
       Sys.set_signal Sys.sigtstp Sys.Signal_default;
       close_ttyfd ()
     end

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
       (fun signal -> if signal <> 0 then Sys.set_signal signal Signal_default) 
       handlers;
     (* more or less following dash's forkchild in jobs.c:847-907 *)
     if outermost && jc
     then begin
         let pid = Unix.getpid () in
         xsetpgid 0 (pgrp pid);
         if not bg 
         then ignore (xtcsetpgrp (pgrp pid));
         Sys.set_signal Sys.sigtstp Signal_default;
         Sys.set_signal Sys.sigttou Signal_default
       end
     else if bg && not jc
     then 
       begin
         Sys.set_signal Sys.sigint Signal_ignore;
         Sys.set_signal Sys.sigquit Signal_ignore
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
     sigunblockall ();
     let status = !real_eval os stmt in 
     real_exit status
  | pid -> 
     sigunblockall (); 
     if jc
     then xsetpgid pid (pgrp pid);
     pid

let rec real_waitpid (rootpid : int) (pid : int) (jc : bool) : int option =
  let ec signal =
    Some (128 + Signal_platform.platform_int_of_ocaml_signal signal)
  in
  let flags = if jc then [Unix.WUNTRACED] else [] in
  let code =
    try match Unix.waitpid flags pid with
        | (_,Unix.WEXITED code) -> Some code
        | (_,Unix.WSIGNALED signal) -> ec signal (* bash, dash behavior *)
        | (_,Unix.WSTOPPED signal) -> ec signal (* bash, dash behavior *)
    with Unix.Unix_error(Unix.EINTR,_,_) -> real_waitpid rootpid pid jc
       | Unix.Unix_error(Unix.ECHILD,_,_) -> gotsigchld := true; None
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
  with Unix.Unix_error(Unix.ECHILD,_,_) -> gotsigchld := false; None
     | Unix.Unix_error(Unix.EINTR,_,_) -> (* got sigchld? *) None

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

let real_file_mtime (path : string) : float option =
  try Some (Unix.stat path).st_mtime
  with Unix.Unix_error(_,_,_) -> None

let real_file_number (path : string) : (int * int) option =
  try let st = Unix.stat path in
      Some (st.st_dev, st.st_ino)
  with Unix.Unix_error(_,_,_) -> None

let real_readdir (path : string) : (string * bool) list =
  try   
    let rec go h acc =
      try 
        let file = Unix.readdir h in
        go h ((file, real_isdir (Filename.concat path file))::acc)
      with End_of_file -> List.rev acc
    in
    go (Unix.opendir path) []
  with Unix.Unix_error(e,_,_) -> []

let real_chdir (path : string) : string option =
  try if real_isdir path 
      then (Unix.chdir path; None)
      else Some ("no such directory " ^ path)
  with Unix.Unix_error(e,_,_) -> Some (Unix.error_message e)

let real_is_tty (fd : int) = Unix.isatty (ExtUnix.file_descr_of_int fd)

type open_flags = Unix.open_flag list

let to_flags = [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_EXCL]
let to_special_flags = [Unix.O_WRONLY]
let clobber_flags = [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_TRUNC]
let from_flags = [Unix.O_RDONLY]
let fromto_flags = [Unix.O_RDWR; Unix.O_CREAT]
let append_flags = [Unix.O_WRONLY; Unix.O_CREAT; Unix.O_APPEND]

let real_open (file:string) (flags:open_flags) : (string,int) either =
  (* TODO 2019-04-10 use umask? *)
  try xopenfile file flags 0o666
  with 
  | Unix.Unix_error(Unix.EEXIST,_,_) -> Left ("cannot create " ^ file ^ ": file exists")
  | Unix.Unix_error(e,_,_) -> Left (Unix.error_message e)

(* uninterruptable read and write, per dash *)
let rec xread (fd:Unix.file_descr) (buff : Bytes.t) ofs : int =
  try Unix.read fd buff ofs (Bytes.length buff - ofs) 
  with Unix.Unix_error(Unix.EPIPE,_,_) -> 0
     | Unix.Unix_error(Unix.EBADF,_,_) -> 0
     | Unix.Unix_error(Unix.EINTR,_,_) -> xread fd buff ofs

let rec xwrite (fd:Unix.file_descr) (buff : Bytes.t) : bool =
  let len = Bytes.length buff in
  try 
    let written = Unix.write fd buff 0 len in
    written = len
  with Unix.Unix_error(Unix.EINTR,_,_) -> xwrite fd buff (* just try again *)
     | Unix.Unix_error(_,_,_) -> false

let real_write_fd (fd:int) (s:string) : bool =
  let buff = Bytes.of_string s in
  xwrite (ExtUnix.file_descr_of_int fd) buff

let real_read_all_fd (fd:int) : string option =
  let rec drain buff ofs =
    let read = xread (ExtUnix.file_descr_of_int fd) buff ofs in
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
    match xread (ExtUnix.file_descr_of_int fd) buff 0 with
    | 0 -> Right None
    | 1 -> Right (Some (Bytes.get buff 0))
    | _ -> Left ("couldn't read " ^ string_of_int fd)
  with Unix.Unix_error(Unix.EPIPE,_,_) -> Left "broken pipe"
     | Unix.Unix_error(Unix.EBADF,_,_) -> Left "no such fd"

let real_read_line_fd (fd:int) backslash_escapes
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

let rec real_savefd (fd:int) : (string,int) either =
  try
    let newfd = Dash.freshfd_ge10 fd in
    if newfd = -1
    then Left "EBADF"
    else if newfd < 0
    then Left ("error duplicating fd " ^ string_of_int fd)
    else Right newfd
  with Unix.Unix_error(Unix.EBADF,_,_) -> Left "EBADF"
     | Unix.Unix_error(Unix.EINTR,_,_) -> real_savefd fd
     | Unix.Unix_error(e,_,_) -> Left (Unix.error_message e ^ ": " ^ string_of_int fd)

let rec real_dup2 (orig_fd:int) (tgt_fd:int) : string option =
  try Unix.dup2 (ExtUnix.file_descr_of_int orig_fd) (ExtUnix.file_descr_of_int tgt_fd); None
  with Unix.Unix_error(EINTR,_,_) -> real_dup2 orig_fd tgt_fd
     | Unix.Unix_error(e,_,_) -> Some (Unix.error_message e  ^ ": " ^ string_of_int orig_fd)

let real_pipe () : int * int =
  let (fd_read,fd_write) = Unix.pipe () in
  (renumber ~cloexec:false fd_read, renumber ~cloexec:false fd_write)

let real_openhere (s : string) : (string,int) either =
  let buff = Bytes.of_string s in
  try
    let (fd_read_orig, fd_write_orig) = Unix.pipe () in
    let fd_read = renumber fd_read_orig in
    let fd_write = renumber fd_write_orig in
    if Bytes.length buff <= 4096 (* from dash *)
    then 
      (* just write it, the pipe can hold it *)
      begin
        ignore (xwrite (ExtUnix.file_descr_of_int fd_write) buff);
        real_close fd_write;
        Right fd_read
      end       
    else 
      (* heredoc is too big for the pipe, so spin up a process to do the writing *)
      match Unix.fork () with
      | 0 -> 
         begin
           real_close fd_read;
           (* ignore SIGINT, SIGQUIT, SIGHUP, SIGTSTP *)
           Sys.set_signal Sys.sigint Sys.Signal_ignore;
           Sys.set_signal Sys.sigquit Sys.Signal_ignore;
           Sys.set_signal Sys.sighup Sys.Signal_ignore;
           Sys.set_signal Sys.sigtstp Sys.Signal_ignore;
           (* SIGPIPE gets default handler... maybe we didn't need the whole heredoc? *)
           Sys.set_signal Sys.sigpipe Sys.Signal_default;
           ignore (xwrite (ExtUnix.file_descr_of_int fd_write) buff);
           exit 0
         end
      | _pid -> 
         begin
           real_close fd_write;
           Right fd_read
         end
  with Unix.Unix_error(e,_,_) -> Left (Unix.error_message e)

let handler signal = add_pending_signal signal

let real_handle_signal signal action =
  if signal <> 0
  then
    let handler =
      match action with
      | None     -> Sys.Signal_default
      | Some  "" -> Sys.Signal_ignore
      | Some cmd -> Sys.Signal_handle handler
    in
    Sys.set_signal signal handler

let rec real_signal_pid signal pid as_pg =
  try Unix.kill (if as_pg then ExtUnix.getpgid pid else pid) signal; true
  with
    Unix.Unix_error(EINTR,_,_) -> real_signal_pid signal pid as_pg (* shouldn't be possible, per `man 2 kill` *)
  | Unix.Unix_error(_e,_,_) -> false
