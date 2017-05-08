open Lem_pervasives_extra
open Fsh_prelude

let shell_env_insert s0 k v : ty_os_state =
  ({ s0 with shell_env = (Pmap.add k v s0.shell_env) })

let os_var_x_null:ty_os_state=  ({ os_empty with shell_env = (Pmap.add "x" "" os_empty.shell_env) })
let os_var_x_set:ty_os_state=  ({ os_empty with shell_env = (Pmap.add "x" "bar" os_empty.shell_env) })
let os_var_x_set_three:ty_os_state=  ({ os_empty with shell_env = (Pmap.add "x" "\"this is three\"" os_empty.shell_env) })

let os_var_x_five:ty_os_state=  ({ os_empty with shell_env = (Pmap.add "x" "5" os_empty.shell_env) })

let os_ifs_spaceandcomma:ty_os_state=  ({ os_empty with shell_env = (Pmap.add "IFS" " ," os_empty.shell_env) })
let os_ifs_comma:ty_os_state=  ({ os_empty with shell_env = (Pmap.add "IFS" "," os_empty.shell_env) })


