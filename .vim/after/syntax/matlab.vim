syntax region matlabCommentFold start=+\(^\s*%.*\n\)\@<!\zs\(\_^\s*%.*\)+ end=+\ze\_^\(\s*%.*\n\)\@!.*$+ transparent fold
syntax match matlabCommentSection +\(^\s*%%\)\@=\zs.*$+ containedin=matlabComment

syn keyword matlabBool true false logical

" Data handling
syn keyword matlabFunc exist single isempty

syn keyword matlabFunc prod sum diff cumsum

" File system
syn keyword matlabFunc fullfile

" Strings
syn keyword matlabFunc strcat fprintf sprintf

" FFT
syn keyword matlabFunc fftn ifftn

syn keyword matlabFunc polyval polyfit

hi link matlabCommentSection SpecialComment
hi link matlabFunc Function
hi link matlabBool Boolean
