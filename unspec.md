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

If the expanded value of ENV is not an absolute pathname, the results are unspecified.

  but also
  4 sh: ENV not absolute

If the expanded value of ENV is not an absolute pathname, the results are unspecified.

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

* 4 sh: asynchronous STDIN

When the command expecting to read standard input is started asynchronously by an interactive shell, it is unspecified whether characters are read by the command or interpreted by the shell.

* 4 sh: history from multiple shells

If more than one instance of the shell is using the same history file, it is unspecified how updates to the history file from those shells interact.

* 4 sh: history removal

It is unspecified when history file entries are physically removed from the history file.

* 4 sh: HISTSIZE unset

If this variable is unset, an unspecified default greater than or equal to 128 shall be used. The maximum number of commands in the history list is unspecified, but shall be at least 128.

* 4 sh: HISTSIZE change

...it is unspecified whether changes made to HISTSIZE after the history file has been initialized are effective.

* 4 sh: MAIL message format

If this variable is set, the shell shall inform the user if the file named by the variable is created or if its modification time has changed. Informing the user shall be accomplished by writing a string of unspecified format to standard error prior to the writing of the next primary prompt string.

* 4 sh: MAILPATH message format

The default message is unspecified. 

* 4 sh: +m terminal signals

If the -m option is not in effect, it is unspecified whether SIGTTIN, SIGTTOU, and SIGTSTP signals are ignored, set to the default action, or caught. If they are caught, the shell shall, in the signal-catching function, set the signal to the default action and raise the signal (after taking any appropriate steps, such as restoring terminal settings).

* 4 sh: vi editing mode EOF

If end-of-file is entered other than at the beginning of the line, the results are unspecified.
