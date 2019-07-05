# Unspecified behavior

Describes the nature of a value or behavior not specified by POSIX.1-2017 which results from use of a valid program construct or valid data input.

The value or behavior may vary among implementations that conform to POSIX.1-2017. An application should not rely on the existence or validity of the value or behavior. An application that relies on any particular value or behavior cannot be assured to be portable across conforming implementations.

## Base Definitions

* 3.38: backspace at beginning of line

If the position about to be printed is at the beginning of the current line, the behavior is unspecified.

* 3.186: form-feed not first in line

If the form-feed is not the first character of an output line, the result is unspecified.

* 3.400: out of horizontal tabs

If the current position is at or past the last defined horizontal tabulation position, the behavior is unspecified

* 3.441: out of vertical tabs

If the current position is at or past the last defined vertical tabulation position, the behavior is unspecified.

* 4.23: invalid variable name

An alternative form of variable assignment:

symbol=value

(where symbol is a valid word delimited by an <equals-sign>, but not a valid name) produces unspecified results.

* 8.2 Internationalization variables: locale mismatch

If these variables specify locale categories that are not based upon the same underlying codeset, the results are unspecified.

* 8.2 Internationalization variables: unknown locale

If the locale value is not recognized by the implementation, the behavior is unspecified.

## Shell & Utilities

* 1.4 Utility Description Defaults: multiple -

Unless otherwise stated, the use of multiple instances of '-' to mean standard input in a single command produces unspecified results.

* 1.4 Utility Description Defaults: escaped newline EOF

If a utility using the escaped <newline> convention detects an end-of-file condition immediately after an escaped <newline>, the results are unspecified.

* 1.4 Utility Description Defaults: diagnostic messages

The format of diagnostic messages for most utilities is unspecified.

* 2.1 Shell introduction: #!

If the first line of a file of shell commands starts with the characters "#!", the results are unspecified.

* 2.4 Reserved words: [[, ]], function, select

The following words may be recognized as reserved words on some implementations (when none of the characters are quoted), causing unspecified results: ...

* 2.4 Reserved words: labels

Words that are the concatenation of a name and a <colon> ( ':' ) are reserved; their use produces unspecified results.

* 2.5.2 Special parameters: "$@"

When the expansion occurs within double-quotes, the behavior is unspecified unless one of the following is true:

-  Field splitting as described in Field Splitting would be performed if the expansion were not within double-quotes (regardless of whether field splitting would have any effect; for example, if IFS is null).

-  The double-quotes are within the word of a ${parameter:-word} or a ${parameter:+word} expansion (with or without the <colon>; see Parameter Expansion) which would have been subject to field splitting if parameter had been expanded instead of word.

* 2.5.2 Special parameters: "$@" with null string

If there are no positional parameters, the expansion of '@' shall generate zero fields, even when '@' is within double-quotes; however, if the expansion is embedded within a word which contains one or more other parts that expand to a quoted null string, these null string(s) shall still produce an empty field, except that if the other parts are all within the same double-quotes as the '@', it is unspecified whether the result is zero fields or one empty field.

* 2.5.3 Shell variables: ENV not absolute

The file need not be executable. If the expanded value of ENV is not an absolute pathname, the results are unspecified.

* 2.5.3 Shell variables: IFS invalid character

If the value of IFS includes any bytes that do not form part of a valid character, the results of field splitting, expansion of '*', and use of the read utility are unspecified.

* 2.5.3 Shell variables: LINENO outside of script or function

If the shell is not currently executing a script or function, the value of LINENO is unspecified.

* 2.5.3 Shell variables: absolute PWD in initial environment

Otherwise, if a value for PWD is passed to the shell in the environment when it is executed, the value is an absolute pathname of the current working directory, and the value does not contain any components that are dot or dot-dot, then it is unspecified whether the shell sets PWD to the value from the environment or sets PWD to the pathname that would be output by pwd -P.

* 2.5.3 Shell variables: PWD insufficient permissions

In cases where PWD is set to the pathname that would be output by pwd -P, if there is insufficient permission on the current working directory, or on any parent of that directory, to determine what that pathname would be, the value of PWD is unspecified.

* 2.5.3 Shell variables: PWD manually set

Assignments to this variable may be ignored. If an application sets or unsets the value of PWD, the behaviors of the cd and pwd utilities are unspecified.

* 2.6 Word expansions: bad $ parse

If an unquoted '$' is followed by a character that is not one of the following:

- A numeric character
- The name of one of the special parameters (see Special Parameters)
- A valid first character of a variable name
- A <left-curly-bracket> ( '{' )
- A <left-parenthesis>

the result is unspecified.

* 2.6.1 Tilde expansion: ~ no HOME

If HOME is unset, the results are unspecified.

* 2.6.2 Parameter expansion: $ invalid name non-digit non-special

[If the name after a parameter isn't a valid name, then] the parameter is a single-character symbol, and behavior is unspecified if that character is neither a digit nor one of the special parameters (see Special Parameters).

* 2.6.2 Parameter expansion: ${#*} and ${#@}

If parameter is '*' or '@', the result of the expansion is unspecified.

* 2.6.3 Command substitution: null bytes

If the output contains any null bytes, the behavior is unspecified.

* 2.6.3 Command substitution: solely redirects

Any valid shell script can be used for command, except a script consisting solely of redirections which produces unspecified results.

* 2.7 Redirection: heredoc EOF token expansion

If the redirection operator is "<<" or "<<-", the word that follows the redirection operator shall be subjected to quote removal; it is unspecified whether any of the other expansions occur.

* 2.7.4 Here document: file descriptor type

It is unspecified whether the file descriptor is opened as a regular file, a special file, or a pipe.

* 2.7.5 Duplicating an Input File Descriptor: bad word

If word evaluates to something [other than an possible fd # or -], the behavior is unspecified.

* 2.7.6 Duplicating an Output File Descriptor: bad word

If word evaluates to something [other than an possible fd # or -], the behavior is unspecified.

* 2.9.1 Simple commands: non-function, non-special assignment visibility

If the command name is not a special built-in utility or function, ... it is unspecified:

- Whether or not the assignments are visible for subsequent expansions in step 4
- Whether variable assignments made as side-effects of these expansions are visible for subsequent expansions in step 4, or in the current shell execution environment, or both

* 2.9.1 Simple commands: special builtins set +a

It is unspecified:

- Whether or not the variables gain the export attribute during the execution of the special built-in utility
- Whether or not export attributes gained as a result of the variable assignments persist after the completion of the special built-in utility

* 2.9.1 Simple commands: functions

It is unspecified:

- Whether or not the variable assignments persist after the completion of the function
- Whether or not the variables gain the export attribute during the execution of the function
- Whether or not export attributes gained as a result of the variable assignments persist after the completion of the function (if variable assignments persist after the completion of the function)

* 2.9.1 Simple commands: subshell reuse for redirections

If there is no command name, any redirections shall be performed in a subshell environment; it is unspecified whether this subshell environment is the same one as that used for a command substitution within the command.

* 2.9.1 Simple commands - command search and execution: unspec utilities

alloc, autoload, bind, bindkey, builtin, bye, caller, cap, chdir, clone, comparguments, compcall, compctl, compdescribe, compfiles, compgen, compgroups, complete, compquote, comptags, comptry, compvalues, declare, dirs, disable, disown, dosh, echotc, echoti, help, history, hist, let, local, login, logout, map, mapfile, popd, print, pushd, readarray, repeat, savehistory, source, shopt, stop, suspend, typeset, whence

* 2.9.1 Simple commands - command search and execution: bad names in local assignment

It is unspecified whether environment variables that were passed to the shell when it was invoked, but were not used to initialize shell variables (see Shell Variables) because they had invalid names, are included in the environment passed to execl() and (if execl() fails as described above) to the new shell.

* 2.9.1 Simple commands - command search and execution: bad names from startup

It is unspecified whether environment variables that were passed to the shell when it was invoked, but were not used to initialize shell variables (see Shell Variables) because they had invalid names, are included in the environment passed to execl() and (if execl() fails as described above) to the new shell.

* 2.9.1 Pipelines: !( syntax

The behavior of the reserved word ! immediately followed by the ( operator is unspecified.

* 2.9.4 Compound commands - case conditional construct: pattern order

The order of expansion and comparison of multiple patterns that label a compound-list statement is unspecified.

* 2.10.2 Shell grammar rules: redirection single field

As specified [for redirection], exactly one field can result (or the result is unspecified), and there are additional requirements on pathname expansion.

* 2.11 Signals and Error Handling: signal ordering

If multiple signals are pending for the shell for which there are associated trap actions, the order of execution of trap actions is unspecified.

* 2.13.1 Pattern Matching a Single Character: unescaped backslash terminator

If a pattern ends with an unescaped <backslash>, it is unspecified whether the pattern does not match anything or the pattern is treated as invalid.

* 2.13.1 Pattern Matching a Single Character: unquoted ^ in bracket

A bracket expression starting with an unquoted <circumflex> character produces unspecified results.

* 2.13.1 Pattern Matching a Single Character: period in bracket matches leading period

It is unspecified whether an explicit <period> in a bracket expression matching list, such as "[.abc]", can match a leading <period> in a filename.

* 2.13.1 Pattern Matching a Single Character: missing terminating bracket

If the pattern contains an open bracket ( '[' ) that does not introduce a bracket expression as in XBD RE Bracket Expression, it is unspecified whether other unquoted pattern matching characters within the same slash-delimited component of the pattern retain their special meanings or are treated as ordinary characters. For example, the pattern "a*[/b*" may match all filenames beginning with 'b' in the directory "a*[" or it may match all filenames beginning with 'b' in all directories with names beginning with 'a' and ending with '['.

* 2.14 break: no enclosing loop

If there is no enclosing loop, the behavior is unspecified.

* 2.14 break: non-lexical loops

If n is greater than the number of lexically enclosing loops and there is a non-lexically enclosing loop in progress in the same execution environment as the break or continue command, it is unspecified whether that loop encloses the command.

* 2.14 continue: no enclosing loop

If there is no enclosing loop, the behavior is unspecified.

* 2.14 continue: non-lexical loops

If n is greater than the number of lexically enclosing loops and there is a non-lexically enclosing loop in progress in the same execution environment as the break or continue command, it is unspecified whether that loop encloses the command.

* 2.14 exec: high-number FDs remain open

If exec is specified without command or arguments, and any file descriptors with numbers greater than 2 are opened with associated redirection statements, it is unspecified whether those file descriptors remain open when the shell invokes another utility.

* 2.14 exit: n not a number, n < 0 || n > 255

The exit status shall be n, if specified, except that the behavior is unspecified if n is not an unsigned decimal integer or is greater than 255.

NOTE: all shells seem to treat the code as mod 255 when positive. negatives cause some errors, though.

* 2.14 export: no arguments

When no arguments are given, the results are unspecified.

* 2.14 readonly: no arguments

When no arguments are given, the results are unspecified.

* 2.14 return: not in function or dot script

If the shell is not currently executing a function or dot script, the results are unspecified.

* 2.14 return: n invalid

If n is not an unsigned decimal integer, or is greater than 255, the results are unspecified.

NOTE: absolutely bonkers behavior.

f() { return 257; }; f; echo $?

```
      smoosh: OUT [257] ERR [] EC [0]
  bash-posix: OUT [1]   ERR [] EC [0]
        bash: OUT [1]   ERR [] EC [0]
        dash: OUT [257] ERR [] EC [0]
   zsh-posix: OUT [257] ERR [] EC [0]
         zsh: OUT [257] ERR [] EC [0]
         osh: OUT [257] ERR [] EC [0]
        mksh: OUT [1]   ERR [] EC [0]
         ksh: OUT [257] ERR [] EC [0]
  yash-posix: OUT [257] ERR [] EC [0]
        yash: OUT [257] ERR [] EC [0]
```

f() { return 257; }; f

```
      smoosh: OUT [] ERR [] EC [1]
  bash-posix: OUT [] ERR [] EC [1]
        bash: OUT [] ERR [] EC [1]
        dash: OUT [] ERR [] EC [1]
   zsh-posix: OUT [] ERR [] EC [1]
         zsh: OUT [] ERR [] EC [1]
         osh: OUT [] ERR [] EC [1]
        mksh: OUT [] ERR [] EC [1]
         ksh: OUT [] ERR [] EC [129]
  yash-posix: OUT [] ERR [] EC [1]
        yash: OUT [] ERR [] EC [1]
```

* 2.14 set: -b format

The following message is written to standard error:

"[%d]%c %s%s\n", <job-number>, <current>, <status>, <job-name>

...

<status>
    Unspecified.
<job-name>
    Unspecified.

* 2.14 set: -o

-o
    Write the current settings of the options to standard output in an unspecified format.
    
* 2.14 set: +x

It is unspecified whether the command that turns tracing off is traced.

* 2.14 set: first argument -

If the first argument is '-', the results are unspecified.

* 2.14 unset: no such variable, function w/o -f

If neither -f nor -v is specified, name refers to a variable; if a variable by that name does not exist, it is unspecified whether a function by that name, if any, shall be unset.



# Undefined behavior

Describes the nature of a value or behavior not defined by POSIX.1-2017 which results from use of an invalid program construct or invalid data input.

The value or behavior may vary among implementations that conform to POSIX.1-2017. An application should not rely on the existence or validity of the value or behavior. An application that relies on any particular value or behavior cannot be assured to be portable across conforming implementations.

## Base Definitions

* 3.133 Display: no terminal

To output to the user's terminal. If the output is not directed to a terminal, the results are undefined.

### Printf format specs

* 5 File format notation: out of horizontal tabs

\t

<tab>

Move the printing position to the next tab position on the current line. If there are no more tab positions remaining on the line, the behavior is undefined.

* 5 File format notation: out of vertical tabs

\v
	
<vertical-tab>

Move the printing position to the start of the next <vertical-tab> position. If there are no more <vertical-tab> positions left on the page, the behavior is undefined.

* 5 File format notation: #

The value shall be converted to an alternative form. For c, d, i, u, and s conversion specifiers, the behavior is undefined.

* 5 File format notation: 0 
  
For other conversion specifiers [than a, A, d, e, E, f, F, g, G, i, o, u, x, and X], the behavior is undefined.

* 5 File format notation: insufficent arguments

The results are undefined if there are insufficient arguments for the format.

* 8 Environment variables: NLSPATH

Setting NLSPATH to override the default system path produces undefined results in the standard utilities and in applications with appropriate privileges.

* 12.1 Utility argument syntax: repetition

If an option that does not have option-arguments is repeated, the results are undefined, unless otherwise stated.

* 12.1 Utility argument syntax:

The use of conflicting mutually-exclusive arguments produces undefined results, unless a utility description specifies otherwise.

# Shell & Utilities

* 1.1.1 System Interfaces: no symlinks

When a file that does not exist is created, the following features ... shall apply unless the utility or function description states otherwise:

If the file is a symbolic link, the effect shall be undefined unless the {POSIX2_SYMLINKS} variable is in effect for the directory in which the symbolic link would be created.

* 1.4 Utility description defaults: non-text

When an input file is described as a "text file", the utility produces undefined results if given input that is not from a text file, unless otherwise stated.

* 1.4 Utility description defaults: non-tty STDOUT

Some of the standard utilities describe their output using the verb display, defined in XBD Display. Output described in the STDOUT sections of such utilities may be produced using means other than standard output. When standard output is directed to a terminal, the output described shall be written directly to the terminal. Otherwise, the results are undefined.

* 2.2.3 Double-Quotes: bad command substitution

Either of the following cases produces undefined results:

    A single-quoted or double-quoted string that begins, but does not end, within the "`...`" sequence

    A "`...`" sequence that begins, but does not end, within the same double-quoted string

but also:
  2.6.3 Command substitution: bad double quotes
  
The search for the matching backquote shall be satisfied by the first unquoted non-escaped backquote; during this search, if a non-escaped backquote is encountered within a shell comment, a here-document, an embedded command substitution of the $(command) form, or a quoted string, undefined results occur. A single-quoted or double-quoted string that begins, but does not end, within the "`...`" sequence produces undefined results.

* 2.6.1 Tilde Expansion: bad login name

If the system does not recognize the login name, the results are undefined.

* 2.14 exit: n not in [0,255]

If n is specified, but its value is not between 0 and 255 inclusively, the exit status is undefined.

* 2.14 trap: SIGKILL/SIGSTOP

Setting a trap for SIGKILL or SIGSTOP produces undefined results.
