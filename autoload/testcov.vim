highlight default TestcovCoveredSign   ctermfg=green
highlight default TestcovUncoveredSign ctermfg=red
call sign_define('testcov_covered', {'text': g:testcov_sign_covered, 'texthl': 'TestcovCoveredSign'})
call sign_define('testcov_uncovered', {'text': g:testcov_sign_uncovered, 'texthl': 'TestcovUncoveredSign'})

function! testcov#Mark(file_pattern = '%')
  if &filetype == 'ruby'
    call s:simplecov_redo_marks(a:file_pattern)
  elseif &filetype == 'cpp' || &filetype == 'c'
    call s:gcov_redo_marks(a:file_pattern)
  endif
endfunction

function! testcov#Refresh(framework='')
  if empty(a:framework) || a:framework == 'SimpleCov'
    call s:simplecov_load(g:testcov_simplecov_path)
  endif
  if empty(a:framework) || a:framework == 'gcov'
    call s:gcov_search_and_discard_caches(g:testcov_gcov_root)
  endif
  call testcov#Mark()
endfunction


function! s:reset_coverage_signs(file_pattern)
  call sign_unplace('testcov', {'buffer': a:file_pattern})
  call setloclist(0, [])
endfunction

function! s:mark_line_coverage(file_pattern, linenr, hits)
  if a:hits == 0
    laddexpr expand(a:file_pattern).':'.a:linenr.': 0 hits'
    let sign_name = 'testcov_uncovered'
  else
    let sign_name = 'testcov_covered'
  endif
  call sign_place(0, 'testcov', sign_name, a:file_pattern, {'lnum': a:linenr, 'priority': g:testcov_sign_priority})
endfunction

let s:gcov_source2line2hits = {}
function! s:gcov_search_and_discard_caches(gcov_root)
  let gcov_notes = glob(a:gcov_root.'/**/*.gcno', 0, 1)
  let s:gcov_source2line2hits = {}
  for line in systemlist('gcov --stdout '.join(gcov_notes, " "))
    let maybe_filename = matchlist(line, '0:Source:\(.*\)')
    if !empty(maybe_filename)
      let current_line2hits = get(s:gcov_source2line2hits, maybe_filename[1], {})
      let s:gcov_source2line2hits[maybe_filename[1]] = current_line2hits
      continue
    endif
    let tag_linenr = matchlist(line, '^[ ]*\([#0-9]\+\)\*\?:[ ]*\([0-9]\+\):')
    if !empty(tag_linenr) && tag_linenr[2] != 0
      let current_line2hits[tag_linenr[2]] = get(current_line2hits, tag_linenr[2], 0) + str2nr(tag_linenr[1])
    endif
  endfor
endfunction

function! s:gcov_redo_marks(file_pattern)
  let full_path = fnamemodify(expand(a:file_pattern), ':p')
  call s:reset_coverage_signs(a:file_pattern)

  for [linenr, hits] in items(get(s:gcov_source2line2hits, full_path, {}))
    call s:mark_line_coverage(a:file_pattern, linenr, hits)
  endfor
endfunction


if has('python3')
  py3 import json
  let s:simplecov_path2coverage = {}

  function! s:simplecov_load(file)
    if !filereadable(a:file)
      return
    endif

    let s:simplecov_path2coverage = {}
    for [_, suite] in items(py3eval("json.load(open(vim.eval('a:file')))"))
      for [path, coverage] in items(suite['coverage'])
        let s:simplecov_path2coverage[path] = coverage
      endfor
    endfor
  endfunction

  function! s:simplecov_redo_marks(file_pattern)
    let full_path = fnamemodify(expand(a:file_pattern), ':p')
    call s:reset_coverage_signs(a:file_pattern)

    let lines = get(s:simplecov_path2coverage, full_path, [])
    if type(lines) == type({}) " SelectCov 0.18 beta also analyze branch coverage
      let lines = lines['lines']
    endif

    let linenr = 1
    for hits_this_line in lines
      if type(hits_this_line) != type(v:none)
        call s:mark_line_coverage(a:file_pattern, linenr, hits_this_line)
      endif
      let linenr += 1
    endfor
  endfunction
else " no python, so define SimpleCov no-ops:
  function! s:simplecov_load(path)
    return
  endfunction
  function! s:simplecov_redo_marks()
    return
  endfunction
endif
