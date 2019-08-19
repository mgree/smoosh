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

* 4 sh: - and --

If both '-' and "--" are given as arguments, or if other operands precede the single <hyphen-minus>, the results are undefined.
