'use strict';

/**********************************************************************/
/* RENDERING: JSON AST -> DOM *****************************************/
/**********************************************************************/
/*
 * We define a variety of functions renderX : JQuery -> X_JSON_AST -> ()
 *
 * renderX(elt, x) will add a rendering of the object X to the DOM
 * node at elt
 *
 * INVARIANTS:
 *   renderX will apply appropriate classes for X, don't do it in advance
 *
 *   renderX checks that the AST is of the right type and has a valid tag
 *
 *   each switch in renderX has the corresponding code from shim.ml as a comment
 *     i.e., always include the code that generates JSON next to the code that renders
 *
 *   classes are of the form X-part1 X-part2 (e.g., redir-src, redir-tgt)
 *
 *   default element to add is a span
 *
 *   field separators are rendered as &nbsp;
 *
 * GLOBAL CLASSES OF IMPORTANCE:
 *   symbolic - for anything treated symbolically
 *
 * IDIOMS AND BEST PRACTICIES
 *   to create new elements for subparts:
 *     let fSrc = $('<span></span>').addClass('redir-File-src').appendTo(elt);
 *
 *   use const and let as much as possible
 */

const fieldSep = '&nbsp;';

/* Redirections *******************************************************/

/* default file redirection fd numbers, by type */
const fileRedirDefault = { 'To': 1,
                           'Clobber': 1,
                           'From': 0,
                           'FromTo': 0,
                           'Append': 1 };

/* default fd duplication fd numbers, by type */
const dupRedirDefault = { 'ToFD': 1,
                          'FromFD': 0 };

/* file redirection symbols */
const fileRedirSym = { 'To': '&gt;', 
                       'Clobber': '&gt;|',
                       'From': '&lt;',
                       'FromTo': '&lt;&gt;',
                       'Append': '&gt;&gt;' };

/* dup redirection symbols */
const dupRedirSym = { 'ToFD': '&gt;&amp;',
                      'FromFD': '&lt;&amp;' }

/* step names */
const stepName = { 'ExpStart': 'Start',
                   'ExpExpand': 'Control code expansion (tildes, variables, commands, arithmetic)',
                   'ExpSplit': 'Field splitting',
                   'ExpPath': 'Pathname expansion',
                   'ExpQuote': 'Quote removal',
                   'ExpError': 'Error',
                   'ExpDone': 'Done' }

function showUnless(def, actual) {
  return def === actual ? "" : String(actual);
}

function renderRedir(elt, redir) {
  console.assert(typeof redir === 'object', 'expected redir object, got %o', redir);
  console.assert('tag' in redir, 'expected tag for statement object');
  console.assert(['File', 'Dup', 'Heredoc'].includes(redir['tag']), 
                 'got weird redir tag %s', redir['tag']);

  const tagClass = 'redir-' + redir['tag']
  const tyClass = tagClass + redir['ty']
  elt.addClass('redir ' + tagClass + ' ' + tyClass);

  switch(redir['tag']) {
    case 'File':
      // | RFile (ty, fd, w) -> 
      //    Assoc [tag "File"; 
      //           ("ty", json_of_redir_type ty); ("src", Int fd); ("tgt", json_of_words w)]
      const fSrc = $('<span></span>').addClass('redir-File-src').appendTo(elt);
      fSrc.append(showUnless(fileRedirDefault[redir['ty']], redir['src']));

      const fSym = $('<span></span>').addClass('redir-File-sym').appendTo(elt);
      fSym.append(fileRedirSym[redir['ty']]);

      const fTgt = $('<span></span>').addClass('redir-File-tgt').appendTo(elt);
      renderWords(fTgt, redir['tgt']);

      break;

    case 'Dup':
      // | RDup (ty, src, tgt) -> 
      //    Assoc [tag "Dup";
      //           ("ty", json_of_dup_type ty); ("src", Int src); ("tgt", Int tgt)]

      const dSrc = $('<span></span>').addClass('redir-Dup-src').appendTo(elt);
      dSrc.append(showUnless(dupRedirDefault[redir['ty']], redir['src']));

      const dSym = $('<span></span>').addClass('redir-Dup-sym').appendTo(elt);
      dSym.append(dupRedirSym[redir['ty']]);

      const dTgt = $('<span></span>').addClass('redir-Dup-tgt').appendTo(elt);
      dTgt.append(String(redir['tgt']));

      break;

    case 'Heredoc':
      // | RHeredoc (ty, src, w) -> 
      //    Assoc [tag "Heredoc";
      //           ("ty", json_of_heredoc_type ty); ("src", Int src); ("w", json_of_words w)]


      const hSrc = $('<span></span>').addClass('redir-Heredoc-src').appendTo(elt);
      hSrc.append(showUnless(0, redir['src']));

      const hSym = $('<span></span>').addClass('redir-Heredoc-sym').appendTo(elt);
      hSym.append('&lt;&lt;');

      // compute a collision-free marker
      let marker = "EOF";
      const lines = redir['w'].split(/\n\r|\n|\r/);
      while (lines.includes(marker)) {
        marker += "EOF";
      }

      hSym.append(marker);
      hSym.append('<br></br>');

      const hText = $('<span></span>').addClass('redir-Heredoc-text').appendTo(elt);
      renderWords(hText, redir['w']);

      const hMarker = $('<span></span>').addClass('redir-Heredoc-marker').appendTo(elt);
      hMarker.append(marker);
      
      break;

    default:
      debugger;
  }
}

/* Statements *********************************************************/

function stmtRedirs(elt, name, stmt) {
  var redirs = $('<span></span>').addClass(name + '-redirs').appendTo(elt);
  for (let i = 0; i < stmt['rs'].length; i += 1) {
    const r = $('<span></span>').appendTo(redirs);    
    renderRedir(r, stmt['rs'][i]);
    
    if (i !== stmt['rs'].length - 1) {
      redirs.append(fieldSep);
    }
  }
}

function stmtBinary(elt, name, sym, stmt) {
  const c1 = $('<span></span>').addClass(name + '-left').appendTo(elt);
  renderStmt(c1, stmt['l']);
  
  elt.append(fieldSep + sym + fieldSep);
  
  const c2 = $('<span></span>').addClass(name + '-right').appendTo(elt);
  renderStmt(c2, stmt['r']);
}

function renderStmt(elt, stmt) {
  console.assert(typeof stmt === 'object', 'expected statement object, got %o', stmt);
  console.assert('tag' in stmt, 'expected tag for statement object');
  console.assert(['Command', 'CommandExpAssign', 'CommandExpArgs', 'CommandExpanded',
                  'Pipe', 'Redir', 'Background', 'Subshell',
                  'And', 'Or', 'Not', 'Semi', 'If', 
                  'While', 'For', 'Case', 'Defun', 'Done'].includes(stmt['tag']), 
                 'got weird statement tag %s', stmt['tag']);

  elt.addClass('stmt stmt-' + stmt['tag']);
  
  switch (stmt['tag']) {
    case 'Command':
      // | Command (assigns, args, rs) -> 
      //    Assoc [tag "Command"; 
      //           ("assigns", List (List.map json_of_assign assigns));
      //           ("args", json_of_words args);
      //           ("rs", json_of_redirs rs)]

      const assigns = $('<span></span>').addClass('simple-assigns').appendTo(elt);
      for (const assign of stmt['assigns']) {
        const a = $('<span></span>').addClass('assign').appendTo(assigns);
        $('<span></span>').addClass('variable').append(assign['var']).appendTo(a);
        
        a.append('=');
        
        const v = $('<span></span>').addClass('variable').appendTo(a);
        renderWords(v, assign['w']);
      }
    
      // if we had an assignment and also have args or redirects, then put a space in
      if (stmt['assigns'].length !== 0 && 
          (stmt['args'].length !== 0 || stmt['rs'].length !== 0)) {
        assigns.append(fieldSep);
      }
    
      const args = $('<span></span>').addClass('simple-args').appendTo(elt);
      renderWords(args, stmt['args']);

      // if we have following redirs, then put a space in
      if (stmt['rs'].length !== 0) {
        args.append(fieldSep);
      }

      stmtRedirs(elt, 'simple', stmt);

      break;

    case 'CommandExpAssign':
    case 'CommandExpArgs':
    case 'CommandExpanded':
      // | CommandExp (assigns, args, rs) -> 
      //    Assoc [tag "CommandExp"; 
      //           ("assigns", List (List.map json_of_inprogress_assign assigns));
      //           ("args", json_of_inprogress_words args);
      //           ("rs", json_of_redirs rs)]

    elt.append('TODO sorry');

    /*
      const assignsExp = $('<span></span>').addClass('simple-assigns').appendTo(elt);
      for (const assign of stmt['assigns']) {
        const a = $('<span></span>').addClass('assign').appendTo(assignsExp);
        $('<span></span>').addClass('variable').append(assign['var']).appendTo(a);
        
        a.append('=');
        
        const v = $('<span></span>').addClass('variable').appendTo(a);

        const vF = $('<span></span>').appendTo(v);
        renderFields(vF, assign['f']);

        const vW = $('<span></span>').appendTo(v);
        renderWords(vW, assign['w']);
      }
    
      // if we had an assignment and also have args or redirects, then put a space in
      if (stmt['assigns'].length !== 0 && 
          (stmt['args'].length !== 0 || stmt['rs'].length !== 0)) {
        assignsExp.append(fieldSep);
      }
    
      const argsExp = $('<span></span>').addClass('simple-args').appendTo(elt);
      const argsF = $('<span></span>').appendTo(v);
      renderFields(vF, stmt['args']['f']);

      const argsW = $('<span></span>').appendTo(v);
      renderWords(vW, stmt['args']['w']);

      // if we have following redirs, then put a space in
      if (stmt['rs'].length !== 0) {
        argsExp.append(fieldSep);
      }

      stmtRedirs(elt, 'simple', stmt);
    */
      break;

    case 'Pipe':
      // | Pipe (bg, cs) -> 
      //    Assoc [tag "Pipe"; ("bg", Bool bg); ("cs", List (List.map json_of_stmt cs))]

      const commands = $('<span></span>').addClass('pipe-commands').appendTo(elt);
      for (let i = 0; i < stmt['cs'].length; i += 1) {
        const c = $('<span></span>').appendTo(commands);
        renderStmt(c, stmt['cs'][i]); 

        if (i != stmt['cs'].length - 1) {
          commands.append(fieldSep + '|' + fieldSep);
        }
      }

      if (stmt['bg']) {
        elt.append(fieldSep + '&amp;');
      }

      break;

    case 'Redir':
      // | Redir (c, rs) -> obj_crs "Redir" c rs

      var command = $('<span></span>').addClass('redir-command').appendTo(elt);
      renderStmt(command, stmt['c']);

      elt.append(fieldSep);

      stmtRedirs(elt, 'redir', stmt);

      break;

    case 'Background':
      // | Background (c, rs) -> obj_crs "Background" c rs

      /* we translate 
           cmds... &
        to
           { cmds & }
        this avoids issues with parsing; in particular,
          cmd1 & ; cmd2 & ; cmd3
        doesn't parse; it must be:
          cmd1 & cmd2 & cmd3
        it's a little too annoying to track "was the last thing
        backgrounded?" so the braces resolve the issue. testing
        indicates that they're semantically equivalent.
      */

      elt.append('{' + fieldSep); 

      var command = $('<span></span>').addClass('bg-command').appendTo(elt);
      renderStmt(command, stmt['c']);

      elt.append(fieldSep);

      stmtRedirs(elt, 'redir', stmt);

      elt.append(fieldSep + '}' + fieldSep + '&amp;'); 

      break;

    case 'Subshell':
      // | Subshell (c, rs) -> obj_crs "Subshell" c rs

      elt.append('('); 

      const subC = $('<span></span>').addClass('subshell-command').appendTo(elt);
      renderStmt(subC, stmt['c']);

      elt.append(fieldSep);

      stmtRedirs(elt, 'subshell', stmt);

      elt.append(')'); 

      break;

    case 'And':
      // | And (c1, c2) -> obj_lr "And" c1 c2

      stmtBinary(elt, 'and', '&amp;&amp;', stmt);

      break;

    case 'Or':
      // | Or (c1, c2) -> obj_lr "Or" c1 c2

      stmtBinary(elt, 'or', '||', stmt);

      break;

    case 'Not':
      // | Not c -> Assoc [tag "Not"; ("c", json_of_stmt c)]

      // for parsing reasons similar to bg above

      elt.append('!' + fieldSep + '{' + fieldSep);

      const cNot = $('<span></span>').addClass('not-stmt').appendTo(elt);
      renderStmt(cNot, stmt['c']);

      elt.append(fieldSep + '}');

      break;

    case 'Semi':
      // | Semi (c1, c2) -> obj_lr "Semi" c1 c2

      stmtBinary(elt, 'semi', ';', stmt);

      break;

    case 'If':
      // | If (c1, c2, c3) -> 
      //    Assoc [tag "If"; ("c", json_of_stmt c1); ("t", json_of_stmt c2); ("e", json_of_stmt c3)]

      elt.append('if' + fieldSep);

      var c1 = $('<span></span>').addClass('if-cond').appendTo(elt);
      renderStmt(c1, stmt['c']);

      elt.append(fieldSep + 'then' + fieldSep);

      var c2 = $('<span></span>').addClass('if-then').appendTo(elt);
      renderStmt(c2, stmt['t']);

      var c3 = $('<span></span>').addClass('if-else').appendTo(elt);
      let cElse = stmt['e'];
      if (typeof cElse === 'object' && 
          'tag' in cElse && cElse['tag'] === 'Command' &&
          cElse['assigns'] === [] && cElse['args'] === [] && cElse['rs'] === []) {
        // one-armed if
        elt.append(';' + fieldSep + 'fi');
      } else if (typeof cElse === 'object' && 
          'tag' in cElse && cElse['tag'] === 'If') {
        // else-if, rely on recursion to get the fi
        c3.append(';' + fieldSep + 'el');
        renderStmt(c3, cElse);
      } else {
        // plain else clause, provide our own fi
        renderStmt(c3, cElse);
        elt.append(';' + fieldSep + 'fi');
      }

      break;

    case 'While':
      // | While (c1, c2) -> 
      //    Assoc [tag "While"; ("cond", json_of_stmt c1); ("body", json_of_stmt c2)]

      const kw   = stmt['cond']['tag'] === 'Not' ? 'until' : 'while';
      const cond = stmt['cond']['tag'] === 'Not' ? stmt['cond']['c'] : stmt['cond'];
  
      elt.append(kw + fieldSep);
      
      var c = $('<span></span>').addClass(kw + '-cond').appendTo(elt);
      renderStmt(c, cond);

      elt.append(';' + fieldSep + 'do');

      var body = $('<span></span>').addClass(kw + '-body').appendTo(elt);
      renderStmt(body, stmt['body']);

      elt.append(';' + fieldSep + 'done');

      break;

    case 'For':
      // | For (x, w, c) -> 
      //    Assoc [tag "For"; ("var", String x); ("args", json_of_words w); ("body", json_of_stmt c)]

      elt.append('for' + fieldSep);
      $('<span></span>').addClass('for-varname variable').append(stmt['var']).appendTo(elt);
      elt.append(fieldSep + 'in' + fieldSep);

      var w = $('<span></span>').addClass('for-args').appendTo(elt);
      renderWords(w, stmt['args']);

      elt.append(';' + fieldSep + 'do');
  
      var body = $('<span></span>').addClass('for-body').appendTo(elt);
      renderStmt(body, stmt['body']);

      elt.append(';' + fieldSep + 'done');

      break;

    case 'Case':
      // | Case (w, cases) -> 
      //    Assoc [tag "Case"; ("args", json_of_words w); ("cases", List (List.map json_of_case cases))]

      elt.append('case' + fieldSep);

      var w = $('<span></span>').addClass('case-args').appendTo(elt);
      renderWords(w, stmt['args']);
  
      elt.append(fieldSep + 'in' + fieldSep);

      // json_of_case (w, c) = Assoc [("pat", json_of_words w); ("stmt", json_of_stmt c)]
      let cases = $('<span></span>').addClass('case-cases').appendTo(elt);
      for (const c of stmt['cases']) {
        let eCase = $('<span></span>').addClass('case').appendTo(cases);

        let pat = $('<span></span>').addClass('case-pattern').appendTo(eCase);
        renderWords(pat, c['pat']);

        eCase.append(')' + fieldSep);

        var body = $('<span></span>').addClass('case-stmt').appendTo(eCase);
        renderStmt(body, c['stmt']);

        eCase.append(fieldSep + ';;');
      }
  
      elt.append(fieldSep + ' esac');

      break;

    case 'Defun':
      // | Defun (f, c) -> Assoc [tag "Defun"; ("name", String f); ("body", json_of_stmt c)]

      // we force { } to make sure it always parses

      let name = $('<span></span>').addClass('defun-name variable').appendTo(elt);
      name.append(stmt['name']);

      elt.append('()' + fieldSep + '{' + fieldSep);

      var body = $('<span></span>').addClass('defun-body').appendTo(elt);
      renderStmt(body, stmt['body']);

      elt.append(fieldSep + '}');

      break;

    case 'Done':
      $('<i></i>').addClass('icon check circle outline').appendTo('elt');

      break;

    default:
      debugger;
  }
};

/* Symbolic values ****************************************************/

function renderSymbolicChar(elt, symbolic) {
  console.assert(typeof symbolic === 'object', 'expected symbolic character object, got %o', symbolic);
  console.assert('tag' in symbolic, 'expected tag for symbolic character object');
  console.assert(['SymCommand', 'SymArith', 'SymPat'].includes(symbolic['tag']), 
                 'got weird symbolic character tag %s', symbolic['tag']);

  elt.addClass('symbolic symbolic-' + symbolic['tag']);

  switch (symbolic['tag']) {
    case 'SymCommand':
      //  | SymCommand c -> Assoc [tag "SymCommand"; ("stmt", json_of_stmt c)]
  
      elt.append('$(');
      var stmt = $('<span></span>').addClass('stmt').appendTo(elt);
      renderStmt(stmt, symbolic['stmt']);
      elt.append(')');
    
      break;

    case 'SymArith':
      //  | SymArith f -> Assoc [tag "SymArith"; ("f", json_of_fields f)]
  
      elt.append('$((');
      elt.append('<span></span>').addClass('param-varname variable').append(control['var']);
      var f = $('<span></span>').appendTo(fmt);
      renderFields(f, control['f']);

      var w = $('<span></span>').appendTo(fmt);
      renderWords(w, control['w']);

      elt.append('))');                 

      break;

    case 'SymPat':
      //  | SymPat (mode, pat, s) -> Assoc [tag "SymPat";
      //                                    ("mode", json_of_substring_mode mode);
      //                                    ("pat", json_of_symbolic_string pat);
      //                                    ("s", json_of_symbolic_string s)]

      elt.append('${');

      var varname = $('<span></span>').addClass('param-varname').appendTo(elt);
      varname.append(control['var']);
      varname.append('=');
      var w = $('<span></span>').appendTo(varname);
      renderWords(w, control['s']);

      var fmt = $('<span></span>').addClass('param-format').appendTo(elt);
      fmt.append(renderSubstring(control['side'], control['mode']));

      var pat = $('<span></span>').appendTo(elt);
      renderFields(pat, control['pat']);

      elt.append('}');

      break;

    default:
      debugger;

  }
};

function renderSymbolicString(elt, ss) {
  console.assert(typeof ss === 'object', 'expected symbolic string list, got %o', ss);
  console.assert('length' in ss, 'expected length field for symbolic string, got %o', ss);

  for (let i = 0;i < ss.length; i += 1) {
    let c = $('<span></span>').addClass('field-char').appendTo(elt);

    switch (typeof ss[i]) {
      case 'string':
        c.append(ss[i])

        break;

      case 'object':
        renderSymbolicChar(c, ss[i]);

        break;

      default:
        debugger;
    }
  }
};

/* Fields, intermediate fields, and expanded words******************************/

function renderFields(elt, fields) {
  console.assert(typeof fields === 'object', 'expected fields list, got %o', fields);
  console.assert('length' in fields, 'expected length field for fields object');

  elt.addClass('fields');

  for (let i = 0; i < fields.length; i += 1) {
    const s = $('<span></span>').addClass('field').appendTo(elt);
    renderSymbolicString(s, fields[i]);

    if (i !== fields.length - 1) {
      $('<span></span>').addClass('field-separator').append(fieldSep).appendTo(elt);
    }
  }
};

function renderTmpField(elt, tf) {
  console.assert(typeof tf === 'object', 'expected temp field character, got %o', tf);
  console.assert('tag' in tf, 'expected tag field in temp field character');
  console.assert(['WFS','FS','Field','QField'].includes(tf['tag']));

  elt.addClass('tmp-field');
  elt.addClass('tmp-field-' + tf['tag']);
  
  switch (tf['tag']) {
    case 'WFS':
      // | WFS -> Assoc [tag "WFS"]
      elt.append(fieldSep);

      break;

    case 'FS':
      // | FS -> Assoc [tag "FS"]
      elt.append(fieldSep);

      break;

    case 'Field':
      // | Field s -> Assoc [tag "Field"; ("s", json_of_symbolic_string s)]

      const f = $('<span></span>').appendTo(elt);
      renderSymbolicString(f, tf['s']);

      break;

    case 'QField':
      // | QField s -> Assoc [tag "QField"; ("s", json_of_symbolic_string s)]

      const qf = $('<span></span>').appendTo(elt);
      qf.append('&ldquo;');
      renderSymbolicString(qf, tf['s']);
      qf.append('&rdquo;');
    
      break;

    default:
      debugger;
  }
}

function renderIntermediateFields(elt, ifs) {
  console.assert(typeof ifs === 'object', 'expected intermediate field list, got %o', ifs);
  console.assert('length' in ifs, 'expected length field for intermediate field list');
  
  elt.addClass('intermediate-fields');

  for (const tmp_field of ifs) {
    const tf = $('<span></span>').appendTo(elt);
    renderTmpField(tf, tmp_field);
  }
}

function renderExpandedWord(elt, w) {
  console.assert(typeof w === 'object', 'expected expanded word character, got %o', w);
  console.assert('tag' in w, 'expected tag field in expanded word character');
  console.assert(['UsrF','ExpS','DQuo','UsrS','EWSym'].includes(w['tag']));

  elt.addClass('expanded-word-' + w['tag']);

  switch (w['tag']) {
    case 'UsrF':
      // | UsrF -> obj "UsrF"

      elt.append(fieldSep);

      break;

    case 'ExpS':
      // | ExpS s -> obj_v "ExpS" s

      elt.addClass('generated');
      elt.append(w['v']);

      break;

    case 'DQuo':
      // | DQuo s -> obj_v "DQuo" s

      elt.addClass('quoted');
      elt.append('"');
      elt.append(w['v']);
      elt.append('"');

      break;

    case 'UsrS':
      // | UsrS s -> obj_v "UsrS" s

      elt.append(w['v']);

      break;

    case 'EWSym':
      // | EWSym sym -> Assoc [tag "EWSym"; ("s", json_of_symbolic sym)]

      let sym = $('<span></span>').appendTo(elt);
      renderSymbolicChar(sym, w['s']);
      break;

    default:
      debugger;
  }
};

function renderExpandedWords(elt, w) {
  console.assert(typeof w === 'object', 'expected expanded word list, got %o', w);
  console.assert('length' in w, 'expected length field for expanded words object');

  for (let i = 0; i < w.length; i += 1) {
    let char = $('<span></span>').addClass('expanded-word').appendTo(elt);
    renderExpandedWord(char, w[i]);
  }
};

/* Words and entries: control codes, etc., pre-expansion ***************/

function renderSubstring(side, mode) {
  console.assert(typeof side === 'string', 'expected string for side, got %o', side);
  console.assert(typeof mode === 'string', 'expected string for mode, got %o', mode);
  console.assert(['Prefix', 'Suffix'].includes(side), 'got weird mode %s', mode);
  console.assert(['Shortest', 'Longest'].includes(mode), 'got weird mode %s', mode);

  var r = side === 'Prefix' ? '#' : '%';
  return mode == 'Shortest' ? r : r + r;
};

function renderFormatChar(format) {
  console.assert(typeof format === 'object', 'expected format object, got %o', format);
  console.assert('tag' in format, 'expected tag for format object');
  console.assert(['Normal', 'Length', 'Default', 'NDefault',
                  'Assign', 'NAssign', 'Error', 'NError',
                  'Alt','NAlt','Substring'].includes(format['tag']), 
                 'got weird format tag %s', format['tag']);

  switch (format['tag']) {
    case 'Normal':
      return '';
    case 'Length':
      return '#'; // but should be special cased
    case 'Default':
      return '-';
    case 'NDefault':
      return ':-';
    case 'Assign':
      return '=';
    case 'NAssign':
      return ':=';
    case 'Error':
      return '?';
    case 'NError':
      return ':?';
    case 'Alt':
      return '+';
    case 'NAlt':
      return ':+';
    case 'Substring':
      return renderSubstring(format['side'], format['mode']);
    default:
      debugger;
  }
};

function renderFormat(elt, format) {
  console.assert(typeof format === 'object', 'expected format object, got %o', format);
  console.assert('tag' in format, 'expected tag for format object');
  console.assert(['Normal', 'Length', 'Default', 'NDefault',
                  'Assign', 'NAssign', 'Error', 'NError',
                  'Alt','NAlt','Substring'].includes(format['tag']), 
                 'got weird format tag %s', format['tag']);

  elt.append(renderFormatChar(format));

  switch (format['tag']) {
    case 'Normal':
    case 'Length':
      break;

    case 'Default':
    case 'NDefault':
    case 'Assign':
    case 'NAssign':
    case 'Error':
    case 'NError':
    case 'Alt':
    case 'NAlt':
      var w = $('<span></span>').appendTo(elt);
      renderWords(w, format['w']);

      break;

    case 'Substring':
      //  | Substring (side,mode,w) -> Assoc [tag "Substring";
      //                                      ("side", json_of_substring_side side);
      //                                      ("mode", json_of_substring_mode mode);
      //                                      ("w", json_of_words w)]

      var fmt = $('<span></span>').addClass('param-format').appendTo(elt);
      fmt.append(renderSubstring(control['side'], control['mode']));

      var w = $('<span></span>').appendTo(elt);
      renderWords(w, control['w']);

      break;

    default:
      debugger;
  }
};

function renderControl(elt, control) {
  console.assert(typeof control === 'object', 'expected control object, got %o', control);
  console.assert('tag' in control, 'expected tag for control object');
  console.assert(['Tilde', 'TildeUser', 'Param', 'LAssign', 'LMatch',
                  'LError', 'Backtick', 'Arith', 'Quote'].includes(control['tag']), 
                 'got weird control tag %s', control['tag']);

  elt.addClass('control-' + control['tag']);
  
  switch (control['tag']) {
    case 'Tilde':
      // | Tilde -> obj "Tilde"

      elt.append('~');

      break;

    case 'TildeUser':
      // | TildeUser user -> Assoc [tag "TildeUser"; ("user", String user)]

      elt.append('~' + control['user']);

      break;

    case 'Param':
      // | Param (x,fmt) -> Assoc [tag "Param"; ("var", String x); ("fmt", json_of_format fmt)]

      elt.append('${');
      // special case for pretty-printing of ${#x}
      if (control['fmt'] === 'Length') {
        elt.append('#');
      }

      $('<span></span>').addClass('param-varname').append(control['var']).appendTo(elt);

      if (control['fmt'] !== 'Length') {
        var fmt = $('<span></span>').addClass('param-format').appendTo(elt);
        renderFormat(fmt, control['fmt']);
      }
      elt.append('}');

      break;

    case 'LAssign':
      // | LAssign (x,f,w) -> Assoc [tag "LAssign"; ("var", String x);
      //                             ("f", json_of_expanded_words f); ("w", json_of_words w)]
    
      elt.append('${');
      $('<span></span>').addClass('param-varname').append(control['var']).appendTo(elt);

      var fmt = $('<span></span>').addClass('param-format').appendTo(elt);
      fmt.append('=');

      var f = $('<span></span>').appendTo(fmt);
      renderExpandedWords(f, control['f']);

      var w = $('<span></span>').appendTo(fmt);
      renderWords(w, control['w']);

      elt.append('}');

      break;

    case 'LMatch':
      // | LMatch (x,side,mode,f,w) -> Assoc [tag "LMatch"; ("var", json_of_fields x);
      //                                      ("side", json_of_substring_side side);
      //                                      ("mode", json_of_substring_mode mode);
      //                                      ("f", json_of_expanded_words f); ("w", json_of_words w)]

      elt.append('${');
      $('<span></span>').addClass('param-varname').append(control['var']).appendTo(elt);

      var fmt = $('<span></span>').addClass('param-format').appendTo(elt);
      fmt.append(renderSubstring(control['side'], control['mode']));

      var f = $('<span></span>').appendTo(elt);
      renderExpandedWords(f, control['f']);

      var w = $('<span></span>').appendTo(elt);
      renderWords(w, control['w']);

      elt.append('}');

      break;

    case 'LError':
      // | LError (x,f,w) -> Assoc [tag "LError"; ("var", String x);
      //                            ("f", json_of_expanded_words f); ("w", json_of_words w)]
      elt.append('${');
      elt.append('<span></span>').addClass('param-varname').append(control['var']);

      var fmt = $('<span></span>').addClass('param-format').appendTo(elt);
      fmt.append('?');

      var f = $('<span></span>').appendTo(fmt);
      renderExpandedWords(f, control['f']);

      var w = $('<span></span>').appendTo(fmt);
      renderWords(w, control['w']);

      elt.append('}');

      break;

      break;

    case 'Backtick':
      // | Backtick c -> Assoc [tag "Backtick"; ("stmt", json_of_stmt c)]

      elt.append('$(');
      var stmt = $('<span></span>').addClass('stmt').appendTo(elt);
      renderStmt(stmt, control['stmt']);
      elt.append(')');

      break;

    case 'Arith':
      // | Arith (f,w) ->  obj_fw "Arith" f w

      elt.append('$((');

      var f = $('<span></span>').appendTo(elt);
      renderExpandedWords(f, control['f']);

      var w = $('<span></span>').appendTo(elt);
      renderWords(w, control['w']);

      elt.append('))');                 

      break;

    case 'Quote':
      // | Quote w -> obj_w "Quote" w

      elt.addClass('quoted');
      elt.append('"');
                 
      var w = $('<span></span>').appendTo(elt);
      renderWords(w, control['w']);

      elt.append('"');

      break;

    default:
      debugger;
  }
};

function renderEntry(elt, entry) {
  console.assert(typeof entry === 'object', 'expected entry object, got %o', entry);
  console.assert('tag' in entry, 'expected tag for entry object');
  console.assert(['S', 'K', 'F', 'ESym'].includes(entry['tag']), 
                 'got weird entry tag %s', entry['tag']);

  elt.addClass('entry-' + entry['tag']);

  switch (entry['tag']) {
    case 'S':
      // | S s -> obj_v "S" s
      elt.append(entry['v']);

      break;

    case 'K':
      // | K k -> Assoc [tag "K"; ("v", json_of_control k)]
      renderControl(elt, entry['v']);

      break;

    case 'F':
      // | F -> obj "F"

      elt.append(fieldSep);

      break;

    case 'ESym':
      // | ESym sym -> Assoc [tag "ESym"; ("v", json_of_symbolic sym)]

      renderSymbolicChar(elt, entry['v']);

      break;

    default:
      debugger;
  }
};

function renderWords(elt, words) {
  console.assert(typeof words === 'object', 'expected words list, got %o', words);
  console.assert('length' in words, 'expected length field for words object, got %o', words);

  elt.addClass('words');

  for (const e of words) {
    let entry = $('<span></span>').appendTo(elt);
    renderEntry(entry, e);
  }
};

/* Top-level step/environment rendering *******************************/

function renderTerm(elt, step) {
  console.assert(typeof step === 'object', 'expected step object, got %o', step);
  console.assert('tag' in step, 'expected tag for step object');
  console.assert(['ExpStart',
                  'ExpExpand','ExpSplit','ExpPath','ExpQuote',
                  'ExpError','ExpDone'].includes(step['tag']),
                 'got weird step tag %o', step['tag']);

  elt.addClass('step-' + step['tag']);

  let label = $('<div></div>').addClass('ui top left attached icon label').appendTo(elt);
  let icon = $('<i></i>').addClass('icon').appendTo(label);
  label.append(stepName[step['tag']]);
  

  let term = $('<div></div>').addClass('term').appendTo(elt);

  switch (step['tag']) {
    case 'ExpStart':
      // | ExpStart w -> obj_w "Start" w     
      icon.addClass('play');

      var w = $('<span></span>').appendTo(term);
      renderWords(w, step['w']);

      break;

    case 'ExpExpand':
      // | ExpExpand (f, w) -> obj_fw "Expand" f w
      icon.addClass('expand');

      var f = $('<span></span>').appendTo(term);
      renderExpandedWords(f, step['f']);

      var w = $('<span></span>').appendTo(term);
      renderWords(w, step['w']);

      break;

    case 'ExpSplit':
      // | ExpSplit (f) -> obj_f "Split" f
      icon.addClass('unlinkify');

      var f = $('<span></span>').appendTo(term);
      renderExpandedWords(f, step['f']);

      break;

    case 'ExpPath':
      // | ExpPath ifs -> Assoc [tag "ExpPath"; ("ifs", json_of_intermediate_fields ifs)]
      icon.addClass('disk outline');

      var ifs = $('<span></span>').appendTo(term);
      renderIntermediateFields(ifs, step['ifs']);

      break;

    case 'ExpQuote':
      // | ExpQuote ifs -> Assoc [tag "ExpQuote"; ("ifs", json_of_intermediate_fields ifs)]
      icon.addClass('quote right');

      var ifs = $('<span></span>').appendTo(term);
      renderIntermediateFields(ifs, step['ifs']);

      break;

    case 'ExpError':
      // | ExpError (f) -> Assoc [tag "Error"; ("msg", json_of_fields f)]
      icon.addClass('warning circle');

      var f = $('<span></span>').appendTo(term);
      renderFields(f, step['msg']);

      break;

    case 'ExpDone':
      // | ExpDone fs -> Assoc [tag "Done"; ("f", json_of_fields fs)]
      icon.addClass('check circle outline');

      var f = $('<span></span>').appendTo(term);
      renderFields(f, step['f']);

      break;

    default:
      debugger;
  };
};

function renderEnv(elt, env) {
  console.assert(typeof env === 'object', 'expected environment object, got %o', env);

  let table = $('<table></table>').addClass('ui unstackable compact table').appendTo(elt);
  let header = $(table).append('<tr><th>Variable</th><th>Value</th></tr>');

  for (const x in env) {
    if (env.hasOwnProperty(x)) {
      let entry = $('<tr></tr>').appendTo(table);

      let varname = $('<td></td>').appendTo(entry);
      varname.append(x);

      let value = $('<td></td>').appendTo(entry);
      renderSymbolicString(value, env[x]);
    }
  }
};

function stepMessage(msg) {
  return msg === '' ? '' : ': ' + msg;
}

function renderExpansionStep(elt, step) {
  console.assert(typeof step === 'object', 'expected step object, got %o', step);
  console.assert('tag' in step, 'expected tag for step object');
  console.assert(['ESTilde', 'ESParam', 'ESCommand', 'ESArith', 'ESSplit', 'ESPath',
                  'ESQuote', 'ESStep', 'ESNested'].includes(step['tag']),
                 'got weird step tag %o', step['tag']);

  // TODO get me
  switch (step['tag']) {
    case 'ESTilde':
      // | ESTilde s -> Assoc [tag "ESTilde"; ("msg", String s)]
  
      elt.append('Tilde expansion' + stepMessage(step['msg']));

      break;

    case 'ESParam':
      // | ESParam s -> Assoc [tag "ESParam"; ("msg", String s)]

      elt.append('Parameter expansion' + stepMessage(step['msg']));
    
      break;

    case 'ESCommand':
      // | ESCommand s -> Assoc [tag "ESCommand"; ("msg", String s)]

      elt.append('Command substitution' + stepMessage(step['msg']));
      
      break;

    case 'ESArith':
      // | ESArith s -> Assoc [tag "ESArith"; ("msg", String s)]
  
      elt.append('Arithmetic expansion' + stepMessage(step['msg']));

      break;

    case 'ESSplit':
      // | ESSplit s -> Assoc [tag "ESSplit"; ("msg", String s)]
    
      elt.append('Field splitting' + stepMessage(step['msg']));

      break;

    case 'ESPath':
      // | ESPath s -> Assoc [tag "ESPath"; ("msg", String s)]
      
      elt.append('Pathname expansion' + stepMessage(step['msg']));

      break;

    case 'ESQuote':
      // | ESQuote s -> Assoc [tag "ESQuote"; ("msg", String s)]
  
      elt.append('Quote removal' + stepMessage(step['msg']));

      break;

    case 'ESStep':
      // | ESStep s -> Assoc [tag "ESStep"; ("msg", String s)]

      if (step['msg'] !== '') {
        elt.append('Expansion step' + stepMessage(step['msg']));
      }

      break;

    case 'ESNested':
      // | ESNested (outer, inner) -> Assoc [tag "ESNested"; ("inner", json_of_expansion_step inner); ("outer", json_of_expansion_step outer)]
  
      renderExpansionStep(elt, step['outer']);
      elt.append(' (');
      renderExpansionStep(elt, step['inner']);
      elt.append(')');
      
      break;

    default:
      debugger;
  }
}

function renderStep(elt, step) {
  console.assert(typeof step === 'object', 'expected step object, got %o', step);
  console.assert('term' in step, 'expected term for step object');
  console.assert('env' in step, 'expected environment for step object');
  console.assert('step' in step, 'expected step description for step object');

  // TODO debug display
  let exp_step = $('<div></div>').addClass('step').appendTo(elt);
  renderExpansionStep(exp_step, step['step']);

  let term = $('<div></div>').addClass('term').appendTo(elt);
  renderTerm(term, step['term']);

  let env = $('<div></div>').addClass('env').appendTo(elt);
  renderEnv(env, step['env']);

};

/**********************************************************************/
/* Handlers ***********************************************************/
/**********************************************************************/

/**
 * Handle expansion: makes the AJAX request for expansion and calls
 * the various rendering functions.
 *
 * By default, it will clear any existing expansion.
 */
// Submit the expansion form
$('#expansionForm').submit(function(e) {
  var url = '/expand/submit';

  var orNone = function(maybeString) {
    if(maybeString === undefined) {
      return 'None';
    } else {
      return maybeString;
    }
  }
  
  var populateResults = function(data) {
    let result = $('#submit-result');
    result.empty();
    result.addClass('ui container');

    $('<h3>Symbolic expansion steps:</h3>').addClass('ui header').appendTo(result);

    let steps = $('<div></div>').addClass('ui segments').appendTo(result);

    for(var i = 0; i < data.length; i++) {
      var step = data[i];

      console.info('%d: term %o env %o step %o', i, step['term'], step['env'], step['step']);

      let elt = $('<div></div>').addClass('expansion-step ui segment').appendTo(steps);
      renderStep(elt, step);
    }
  }

  $.ajax({
    type: 'POST',
    url: url,
    data: $('#expansionForm').serialize(),
    success: function(data) {
      populateResults(JSON.parse(data))
    },
  });

  e.preventDefault();
});

/**
 * Clears any existing expansion.
 */
$('#clear').click(function (e) {
  $('#submit-result').empty();
});
