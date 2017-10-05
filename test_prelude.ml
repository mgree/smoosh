open Fsh

let shell_env_insert s0 k v : ty_os_state =
  ({ s0 with shell_env = (Pmap.add k v s0.shell_env) })

let add_literal_env_string s0 k v = shell_env_insert s0 k (Fsh.stringToSymbolicString v)

let os_var_x_null:ty_os_state= add_literal_env_string os_empty "x" ""
let os_var_x_set:ty_os_state = add_literal_env_string os_empty "x" "bar"
let os_var_x_set_three:ty_os_state= add_literal_env_string os_empty "x" "\"this is three\""

let os_var_x_five:ty_os_state= add_literal_env_string os_empty "x" "5"

let os_ifs_spaceandcomma:ty_os_state= add_literal_env_string os_empty "IFS" " ,"
let os_ifs_comma:ty_os_state= add_literal_env_string os_empty "IFS" ","


