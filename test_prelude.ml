open Fsh

let add_literal_env_string k v s0 = set_param k (Fsh.stringToSymbolicString v) s0

let os_var_x_null:ty_os_state= add_literal_env_string "x" "" os_empty
let os_var_x_set:ty_os_state = add_literal_env_string "x" "bar" os_empty
let os_var_x_set_three:ty_os_state= add_literal_env_string "x" "\"this is three\"" os_empty

let os_var_x_five:ty_os_state= add_literal_env_string "x" "5" os_empty

let os_ifs_spaceandcomma:ty_os_state= add_literal_env_string "IFS" " ," os_empty
let os_ifs_comma:ty_os_state= add_literal_env_string "IFS" "," os_empty


