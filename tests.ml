open Lem_pervasives_extra
open Expansion

let rec fields_to_string = function
[] -> ""
| (Field(s)::rst) -> s ^ fields_to_string rst
| (QField(s)::rst) -> s ^ fields_to_string rst
| (WFS::rst) -> "<<WFS>>" ^ fields_to_string rst
| (FS::rst) -> "<<FS>>" ^ fields_to_string rst

(* RErr test_name expected got *)
type result = Ok | RErr of string * fields * fields

let check_expansion (test_name, s0, w_in, f_expected):result=
  (let (s1, f_out) = (full_expansion s0 w_in) in
  if (listEqualBy (=) f_out f_expected)
  then Ok
  else RErr( test_name, f_expected, f_out))

let os_empty:ty_os_state=  ({
    shell_env = (Pmap.empty compare);
  })

let os_var_x_null:ty_os_state=  ({ os_empty with shell_env = (Pmap.add "x" "" os_empty.shell_env) })
let os_var_x_set:ty_os_state=  ({ os_empty with shell_env = (Pmap.add "x" "bar" os_empty.shell_env) })
let os_var_x_set_three:ty_os_state=  ({ os_empty with shell_env = (Pmap.add "x" "\"this is three\"" os_empty.shell_env) })

let os_ifs_spaceandcomma:ty_os_state=  ({ os_empty with shell_env = (Pmap.add "IFS" " ," os_empty.shell_env) })
let os_ifs_comma:ty_os_state=  ({ os_empty with shell_env = (Pmap.add "IFS" "," os_empty.shell_env) })

(* TODO: tests for variable assignment (will have to check ending state as well) *)
let expansion_tests:(string*ty_os_state*(entry)list*fields)list=
 ([
    ("plain string foo", os_empty, [S "foo"], ["foo"]);
    ("expand tilde without username", { os_empty with shell_env = (Pmap.add "HOME" "/home/testuser" os_empty.shell_env) }, [K Tilde], ["/home/testuser"]);
    ("normal paramater lookup of unset variable", os_empty, [K (Param("x", Normal))], []);
    ("paramter length of unset variable", os_empty, [K (Param("x", Length))], ["0"]);

    ("ndefault parameter lookup on variable set to null replaces word", os_var_x_null, [K (Param("x", (NDefault [S "foo"])))], ["foo"]);
    ("default parameter lookup on variable set to null is null", os_var_x_null, [K (Param("x", (Default [S "foo"])))], []);

    ("paramter length of set variable is the length of the string", os_var_x_set,  [K (Param("x", Length))], ["3"]);
    ("parameter lookup on set variable returns the variable's value", os_var_x_set,[K (Param("x", (Default [S "foo"])))], ["bar"]);
    ("alternate parameter lookup on set variable does not return the variable's value", os_var_x_set, [K (Param("x", (Alt [S "foo"])))], ["foo"]);

    ("Single assignment", os_var_x_set, [S "bar"; K (Param("x", Normal))], ["barbar"]);

    ("Single assignment", os_empty, [S "bar"; K (Param("x", (Assign [S "foo"])))], ["barfoo"]);

    (* ${x=${x=foo}bar${x=baz}}
     * should return foobarfoo
     * x is set to foobarfoo at the end *)
    ("Nested assignment statements", os_empty,
      [K (Param("x", (Assign [K (Param("x", (Assign [S "foo"]))); S "bar"; K (Param("x", (Assign [S "baz"])))])))], ["foobarfoo"]);

    (* ${y=${x:+foo}rab${x+oof}}
     * should return raboof
     * y is set to raboof and x is null at the end *)
    ("Alternate parameter lookups on a variable set to null", os_var_x_null,
      [K (Param("y", (Assign [K (Param("x", (NAlt [S "foo"]))); S "rab"; K (Param("x", (Alt [S "oof"])))])))], ["raboof"]);

    (* ${x:-foo}bar${x-baz}
     * should return foobar
     * x is null at the end *)
    ("Default parameter lookups on a variable set to null", os_var_x_null,
      [K (Param("x", (NDefault [S "foo"]))); S "bar"; K (Param("x", (Default [S "baz"])))], ["foobar"]);

    ("Field splitting parameter expansions, no quotes", os_empty,
      [K (Param("x", (Default [S "a b c"])))], ["a"; "b"; "c"]);

    ("Field splitting parameter expansions, quoted", os_empty,
      [K (Param("x", (Default [DQ "a b c"])))], ["a b c"]);

    ("Field splitting w/ IFS set to ' ,'; commas force field separation", os_ifs_spaceandcomma,
      [K (Param("x", (Assign [S ",b,c"])))], [""; "b"; "c"]);

    (* This shows it is valid to represent the empty string with the empty list above *)
    ("Field splitting w/ IFS set to ' ,'; commas force field separation after parameter expansion", os_ifs_spaceandcomma,
      [S "a"; K (Param("x", (Assign [S ",b,c"])))], ["a"; "b"; "c"]);

    ("Field splitting w/ IFS set to ' ,'; spaces do not force field separation", os_ifs_spaceandcomma,
      [K (Param("x", (Assign [S " b,c"])))], ["b"; "c"]);

    ("Field splitting when IFS is just ','", os_ifs_comma,
      [S "a,b,c"], ["a,b,c"]);

    ("Field splitting when IFS is just ','", os_ifs_comma,
      [S "a b c"], ["a b c"]);

    ("Field splitting when IFS is just ','", os_ifs_comma,
      [S ",,foo,,"], [",,foo,,"]);

    ("Field splitting when IFS is just ','", os_ifs_comma,
      [K (Param("x", (Default [S ",,foo,,"])))], ["";"";"foo";""]);

    ("Field splitting ignores quote characters in expansion", os_empty,
      [S "\"this is three\""], ["\"this is three\""]);

    ("String inside control quote does not field split", os_empty,
      [K (Quote [S "a b c"])], ["a b c"]);

    ("Quoted paramter expansion does not field split", os_var_x_set_three,
      [K (Quote [K (Param("x", Normal))])], ["\"this is three\""]);

    ("Quoted field is combined with adjacent fields when there is no ifs separators", os_var_x_set_three,
      [S "foo"; K (Quote [K (Param("x", Normal))]); S "bar"], ["foo\"this is three\"bar"]);

    ("Quoted field is combined with adjacent fields when ifs separators are inside the quoted section", os_var_x_set_three,
      [S "foo"; K (Quote [S " "; K (Param("x", Normal)); S " "]); S "bar"], ["foo \"this is three\" bar"]);

    ("Quoted field is a separate field when ifs separators are outside the quoted section", os_var_x_set_three,
      [S "foo "; K (Quote [K (Param("x", Normal))]); S " bar"], ["foo"; "\"this is three\""; "bar"]);

    ("Quoted field is a separate field when ifs separators are outside the quoted section", os_var_x_set_three,
      [K (Param("y", Default [S "foo "])); K (Quote [K (Param("x", Normal))]); K (Param("y", Default [S " bar"]))], ["foo"; "\"this is three\""; "bar"]);

  ])
