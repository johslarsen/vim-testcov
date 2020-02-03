highlight default TestcovCoveredSign   ctermfg=green
highlight default TestcovUncoveredSign ctermfg=red
call sign_define('testcov_covered', {'text': g:testcov_sign_covered, 'texthl': 'TestcovCoveredSign'})
call sign_define('testcov_uncovered', {'text': g:testcov_sign_uncovered, 'texthl': 'TestcovUncoveredSign'})

function! testcov#Mark(...)
  let file_pattern = a:0 >= 1 ? a:1 : "%"
  if &filetype == 'ruby'
    call s:simplecov_redo_marks(file_pattern)
  elseif &filetype == 'cpp' || &filetype == 'c'
    call s:gcov_redo_marks(file_pattern)
  endif
endfunction

function! testcov#Refresh(...)
  let framework = a:0 >= 1 ? a:1 : ''
  if empty(framework) || framework == 'SimpleCov'
    call s:simplecov_load(g:testcov_simplecov_path)
  endif
  if empty(framework) || framework == 'gcov'
    call s:gcov_load(g:testcov_gcov_root)
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


if has('python3')
  py3file <sfile>:p:h/gcov.py
  let s:gcov_src2line2hits = {}
  function! s:gcov_load(gcov_root)
    let gcnos = glob(a:gcov_root.'/**/*.gcno', 0, 1)
    let s:gcov_src2line2hits = py3eval('gcov_src2line2hits(["'.join(gcnos, '","').'"], "'.getcwd().'")')
  endfunction

  function! s:gcov_redo_marks(file_pattern)
    let full_path = fnamemodify(expand(a:file_pattern), ':p')
    call s:reset_coverage_signs(a:file_pattern)

    for [linenr, hits] in items(get(s:gcov_src2line2hits, full_path, {}))
      call s:mark_line_coverage(a:file_pattern, linenr, hits)
    endfor
  endfunction


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
else " no python, so define no-ops for functionality that depends on it
  function! s:simplecov_load(path)
  endfunction
  function! s:simplecov_redo_marks()
  endfunction
  function! s:gcov_load(gcov_root)
  endfunction
  function! s:gcov_redo_marks(file_pattern)
  endfunction
endif
