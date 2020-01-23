if exists("g:loaded_testcov") || &cp
  finish
endif
let g:loaded_testcov = 1

command -nargs=? TestcovRefresh call testcov#Refresh(<f-args>)
command -nargs=? -complete=file TestcovMark call testcov#Mark(<f-args>)

if !exists("g:testcov_simplecov_path")
  let g:testcov_simplecov_path = "coverage/.resultset.json"
endif

if !exists("g:testcov_sign_priority")
  let g:testcov_sign_priority = 10
endif
if !exists("g:testcov_sign_covered")
  let g:testcov_sign_covered = "✓"
endif
if !exists("g:testcov_sign_uncovered")
  let g:testcov_sign_uncovered = "X"
endif
