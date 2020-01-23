highlight default TestcovCoveredSign   ctermfg=green
highlight default TestcovUncoveredSign ctermfg=red
call sign_define('testcov_covered', {'text': g:testcov_sign_covered, 'texthl': 'TestcovCoveredSign'})
call sign_define('testcov_uncovered', {'text': g:testcov_sign_uncovered, 'texthl': 'TestcovUncoveredSign'})

function! testcov#Mark(file_pattern = '%')
  if &filetype == 'ruby'
    call s:simplecov_redo_marks(a:file_pattern)
  endif
endfunction

function! testcov#Refresh(framework='')
  if empty(a:framework) || a:framework == 'SimpleCov'
    call s:simplecov_load(g:testcov_simplecov_path)
  endif
  call testcov#Mark()
endfunction

function! s:mark_line_coverage(file_pattern, hits_per_line)
  call sign_unplace('testcov', {'buffer': a:file_pattern})
  call setloclist(0, [])

  for [linenr, hits] in a:hits_per_line
    if hits == 0
      laddexpr expand(a:file_pattern).':'.linenr.': 0 hits'
      let sign_name = 'testcov_uncovered'
    else
      let sign_name = 'testcov_covered'
    endif
    call sign_place(0, 'testcov', sign_name, a:file_pattern, {'lnum': linenr, 'priority': g:testcov_sign_priority})
  endfor
endfunction

if has('python3')
  py3 import json
  let s:simplecov_path2coverage = {}

  function! s:simplecov_load(file)
    if !filereadable(a:file)
      return
    endif

    for [_, suite] in items(py3eval("json.load(open(vim.eval('a:file')))"))
      let s:simplecov_path2coverage = suite['coverage']
    endfor
  endfunction

  function! s:simplecov_redo_marks(file_pattern)
    let full_path = fnamemodify(expand(a:file_pattern), ':p')
    let hits_per_line = []
    let l = 1
    for hits_this_line in get(s:simplecov_path2coverage, full_path, {'lines':[]})['lines']
      if type(hits_this_line) != type(v:none)
        call add(hits_per_line, [l, hits_this_line])
      endif
      let l += 1
    endfor
    call s:mark_line_coverage(a:file_pattern, hits_per_line)
  endfunction
else " no-ops
  function! s:simplecov_load(path)
    return
  endfunction
  function! s:simplecov_redo_marks()
    return
  endfunction
endif
