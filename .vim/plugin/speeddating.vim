" speeddating.vim - Use CTRL-A/X to increment dates, times, and more
" Maintainer:   Tim Pope
" Last Change:  2008 Jan 29
" GetLatestVimScripts: 2120 1 :AutoInstall: speeddating.vim

" Greatly enhanced <C-A>/<C-X>.  Try these keys on various numbers in the
" lines below.  You can also give a count (e.g., 4<C-A>).

" Fri, 31 Dec 1999 23:59:59 +0000
" 2008-01-05T04:59:59Z
" 1865-04-15
" 11/Sep/01
" January 14th, 1982
" 11:55 AM
" 3rd
" XXXVIII

" Try selecting the following lines in visual line mode, positioning the
" cursor in the last column (so it's on top of a number), and pressing <C-A>.

"        I
"       II
"      III
"       IV
"        V

" Also try below to see what happens when the field is missing (alphabetical
" characters can be used in visual mode only, as they overlap with roman
" numerals):

" Z
" 
" 
" 
" 
" 
" 

" The :SpeedDatingFormat command can be used to define custom date and time
" formats.  Invoke ":SpeedDatingFormat!" for help.
"
" Two additional mappings:
" d<C-A>  change the timestamp under the cursor to the current time in UTC
" d<C-X>  change the timestamp under the cursor to the current local time
"
" Caveats:
" - Completely timezone ignorant.
" - Gregorian calendar always used.
" - Beginning a format with a digit causes Vim to treat leading digits as a
"   count instead.  To work around this escape it with %[] instead (e.g.,
"   %[2]0%0y%0m%0d%* is a decent format for DNS serials).

" Licensed under the same terms as Vim itself.

" Initialization {{{1

if exists("g:loaded_speeddating") || &cp || v:version < 700
    finish
endif
let g:loaded_speeddating = 1

let s:cpo_save = &cpo
set cpo&vim

let g:speeddating_handlers = []

let s:install_dir = expand("<sfile>:p:h:h")

" }}}1
" Utility Functions {{{1

function! s:function(name)
    return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '<SNR>\d\+_'),''))
endfunction

" In Vim, -4 % 3 == -1.  Let's return 2 instead.
function! s:mod(a,b)
    if a:a < 0 && a:b > 0 || a:a > 0 && a:b < 0
        return (a:a % a:b) + a:b
    else
        return a:a % a:b
    endif
endfunction

" In Vim, -4 / 3 == -1.  Let's return -2 instead.
function! s:div(a,b)
    if a:a < 0 && a:b > 0
        return (a:a-a:b+1)/a:b
    elseif a:a > 0 && a:b < 0
        return (a:a-a:b-1)/a:b
    else
        return a:a / a:b
    endif
endfunction

function! s:match(...)
    let b = call("match",a:000)
    let e = call("matchend",a:000)
    let s = call("matchlist",a:000)
    if s == []
        let s = ["","","","","","","","","",""]
    endif
    return [b,e] + s
endfunction

function! s:findatoffset(string,pattern,offset)
    let line = a:string
    let curpos = 0
    let offset = a:offset
    while strpart(line,offset,1) == " "
        let offset += 1
    endwhile
    let [start,end,string;caps] = s:match(line,a:pattern,curpos,0)
    while start >= 0
        if offset >= start && offset < end
            break
        endif
        let curpos = start + 1
        let [start,end,string;caps] = s:match(line,a:pattern,curpos,0)
    endwhile
    return [start,end,string] + caps
endfunction

function! s:findinline(pattern)
    return s:findatoffset(getline('.'),a:pattern,col('.')-1)
endfunction

function! s:replaceinline(start,end,new)
    let line = getline('.')
    let before_text = strpart(line,0,a:start)
    let after_text = strpart(line,a:end)
    " If this generates a warning it will be attached to an ugly backtrace.
    " No warning at all is preferable to that.
    silent call setline('.',before_text.a:new.after_text)
    call setpos("'[",[0,line('.'),strlen(before_text)+1,0])
    call setpos("']",[0,line('.'),a:start+strlen(a:new),0])
endfunction

" }}}1
" Normal Mode {{{1

function! s:increment(increment)
    for handler in s:time_handlers + g:speeddating_handlers
        let pattern = type(handler.regexp) == type(function('tr')) ? handler.regexp() : handler.regexp
        let [start,end,string;caps] = s:findinline('\C'.pattern)
        if string != ""
            let [repl,offset] = handler.increment(string,col('.')-1-start,a:increment)
            if offset < 0
                let offset += strlen(repl) + 1
            endif
            if repl != ""
                call s:replaceinline(start,end,repl)
                call setpos('.',[0,line('.'),start+offset,0])
                silent! call repeat#set("\<Plug>SpeedDating" . (a:increment < 0 ? "Down" : "Up"),a:increment < 0 ? -a:increment : a:increment)
                return
            endif
        endif
    endfor
    if a:increment > 0
        exe "norm! ". a:increment."\<C-A>"
    else
        exe "norm! ".-a:increment."\<C-X>"
    endif
    silent! call repeat#set("\<Plug>SpeedDating" . (a:increment < 0 ? "Down" : "Up"),a:increment < 0 ? -a:increment : a:increment)
endfunction

" }}}1
" Visual Mode {{{1

function! s:setvirtcol(line,col)
    call setpos('.',[0,a:line,a:col,0])
    while virtcol('.') < a:col
        call setpos('.',[0,a:line,col('.')+1,0])
    endwhile
    while virtcol('.') > a:col
        call setpos('.',[0,a:line,col('.')-1,0])
    endwhile
    return col('.') + getpos('.')[3]
endfunction

function! s:chars(string)
    return strlen(substitute(a:string,'.','.','g'))
endfunction

function! s:incrementstring(string,offset,count)
    let repl = ""
    let offset = -1
    for handler in s:time_handlers + g:speeddating_handlers + s:visual_handlers
        let pattern = type(handler.regexp) == type(function('tr')) ? handler.regexp() : handler.regexp
        let [start,end,string;caps] = s:findatoffset(a:string,'\C'.pattern,a:offset)
        if string != ""
            let [repl,offset] = handler.increment(string,a:offset,a:count)
            if repl != ""
                break
            endif
        endif
    endfor
    if offset < 0
        let offset += strlen(repl) + 1
    endif

    if repl != ""
        let before_text = strpart(a:string,0,start)
        let change = s:chars(repl) - s:chars(string)
        if change < 0 && before_text !~ '\w$'
            let offset -= change
            let repl = repeat(' ',-change) . repl
        elseif change > 0 && before_text =~ ' $'
            let before_text = substitute(before_text,' \{1,'.change.'\}$','','')
            let before_text = substitute(before_text,'\w$','& ','')
            let start = strlen(before_text)
        endif
        let offset += start
        let repl = before_text.repl.strpart(a:string,end)
    endif
    return [repl,offset,start,end]
endfunction

function! s:incrementvisual(count)
    let ve = &ve
    set virtualedit=all
    exe "norm! gv\<Esc>"
    let vcol = virtcol('.')
    let lnum = line("'<")
    let lastrepl = ""
    call s:setvirtcol(lnum,vcol)
    call setpos("'[",[0,line("'<"),1,0])
    while lnum <= line("'>")
        call s:setvirtcol(lnum,vcol)
        let [repl,offset,start,end] = s:incrementstring(getline('.'),col('.')-1,a:count)
        if repl == "" && lastrepl != ""
            call setpos(".",[0,lnum-1,laststart,0])
            let start = s:setvirtcol(lnum,virtcol('.'))
            call setpos(".",[0,lnum-1,lastend,0])
            let end = s:setvirtcol(lnum,virtcol('.'))
            call s:setvirtcol(lnum,vcol)
            if strpart(getline('.'),start,end-start) =~ '^\s*$'
                let before_padded = printf("%-".start."s",strpart(getline('.'),0,start))
                let tweaked_line  = before_padded.strpart(lastrepl,laststart,lastend-laststart).strpart(getline('.'),end)
                let [repl,offset,start,end] = s:incrementstring(tweaked_line,col('.')-1,a:count*(lnum-lastlnum))
            endif
        elseif repl != ""
            let [lastrepl,laststart,lastend,lastlnum] = [repl,start,end,lnum]
        endif
        if repl != ""
            silent call setline('.',repl)
        endif
        let lnum += 1
    endwhile
    let &ve = ve
    call setpos("']",[0,line('.'),col('$'),0])
endfunction

" }}}1
" Visual Mode Handlers {{{1

let s:visual_handlers = []

function! s:numberincrement(string,offset,increment)
    let n = (a:string + a:increment)
    if a:string =~# '^0x.*[A-F]'
        return [printf("0x%X",n),-1]
    elseif a:string =~# '^0x'
        return [printf("0x%x",n),-1]
    elseif a:string =~# '^00*[^0]'
        return [printf("0%o",n),-1]
    else
        return [printf("%d",n),-1]
    endif
endfunction

let s:visual_handlers += [{'regexp': '-\=\<\%(0x\x\+\|\d\+\)\>', 'increment': s:function("s:numberincrement")}]

function! s:letterincrement(string,offset,increment)
    return [nr2char((char2nr(toupper(a:string)) - char2nr('A') + a:increment) % 26 + (a:string =~# '[A-Z]' ? char2nr('A') : char2nr('a'))),-1]
endfunction

let s:visual_handlers += [{'regexp': '\<[A-Za-z]\>', 'increment': s:function("s:letterincrement")}]

" }}}1
" Ordinals {{{1

function! s:ordinalize(number)
    let n = a:number
    let a = n < 0 ? -n : +n
    if a % 100 == 11 || a % 100 == 12 || a % 100 == 13
        return n."th"
    elseif a % 10 == 1
        return n."st"
    elseif a % 10 == 2
        return n."nd"
    elseif a % 10 == 3
        return n."rd"
    else
        return n."th"
    endif
endfunction

function! s:ordinalincrement(string,offset,increment)
    return [s:ordinalize(a:string+a:increment),-1]
endfunction

let g:speeddating_handlers += [{'regexp': '-\=\<\d\+\%(st\|nd\|rd\|th\)\>', 'increment': s:function("s:ordinalincrement")}]

" }}}1
" Roman Numerals {{{1

" Based on similar functions from VisIncr.vim

let s:a2r = [[1000, 'm'], [900, 'cm'], [500, 'd'], [400, 'cd'], [100, 'c'],
            \             [90 , 'xc'], [50 , 'l'], [40 , 'xl'], [10 , 'x'],
            \             [9  , 'ix'], [5  , 'v'], [4  , 'iv'], [1  , 'i']]

function! s:roman2arabic(roman)
    let roman  = tolower(a:roman)
    let sign   = 1
    let arabic = 0
    while roman != ''
        if roman =~ '^[-n]'
            let sign = -sign
        endif
        for [numbers,letters] in s:a2r
            if roman =~ '^'.letters
                let arabic += sign * numbers
                let roman = strpart(roman,strlen(letters)-1)
                break
            endif
        endfor
        let roman = strpart(roman,1)
    endwhile

    return arabic
endfunction

function! s:arabic2roman(arabic)
  if a:arabic <= 0
      let arabic = -a:arabic
      let roman = "n"
  else
      let arabic = a:arabic
      let roman = ""
  endif
  for [numbers, letters] in s:a2r
      let roman .= repeat(letters,arabic/numbers)
      let arabic = arabic % numbers
  endfor
  return roman
endfunction

" }}}1
" Time Helpers {{{1

" approximate
let s:offset = strftime("%d",86400)*24+strftime("%H",86400)-48

let s:days_engl   =["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
let s:days_abbr   =map(range(86400*3+43200-s:offset*3600,86400*12,86400),'strftime("%a",v:val)')[0:6]
let s:days_full   =map(range(86400*3+43200-s:offset*3600,86400*12,86400),'strftime("%A",v:val)')[0:6]

let s:months_engl =["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
let s:months_abbr =map(range(86400*2,86400*365,86400*31),'strftime("%b",v:val)')
let s:months_full =map(range(86400*2,86400*365,86400*31),'strftime("%B",v:val)')

function! s:ary2pat(array)
    return '\%('.join(a:array,'\|').'\)'
    return '\%('.join(map(copy(a:array),'substitute(v:val,"[[:alpha:]]","[\\u&\\l&]","g")'),'\|').'\)'
endfunction

function! s:initializetime(time)
    call extend(a:time,{'y':2000,'b':1,'d':0,'h':0,'m':0,'s':0},"keep")
    if get(a:time,'b','') !~ '^\d*$'
        let full = index(s:months_full ,a:time.b,0,1) + 1
        let engl = index(s:months_engl ,a:time.b,0,1) + 1
        let abbr = index(s:months_abbr ,a:time.b,0,1) + 1
        if full
            let a:time.b = full
        elseif engl
            let a:time.b = engl
        elseif abbr
            let a:time.b = abbr
        else
            let a:time.b = 1
        endif
    endif
    if has_key(a:time,'p')
        let a:time.h = a:time.h % 12
        if a:time.p ==? "PM"
            let a:time.h += 12
        endif
        call remove(a:time,"p")
    endif
    if a:time.y !~ '^\d*$'
        let a:time.y = s:roman2arabic(a:time.y)
    elseif a:time.y =~ '^-\=0..'
        let a:time.y = substitute(a:time.y,'0\+','','')
    elseif a:time.y < 38 && a:time.y >= 0
        let a:time.y += 2000
    elseif a:time.y < 100 && a:time.y >= 0
        let a:time.y += 1900
    endif
    if a:time.d == 0 && has_key(a:time,'w')
        let full = index(s:days_full ,a:time.w,0,1)
        let engl = index(s:days_engl ,a:time.w,0,1)
        let abbr = index(s:days_abbr ,a:time.w,0,1)
        let any = full > 0 ? full : (engl > 0 ? engl : (abbr > 0 ? abbr : a:time.w))
        let a:time.d = s:mod(any - s:jd(a:time.y,a:time.b,1),7)
        call remove(a:time,'w')
    endif
    if a:time.d == 0
        let a:time.d = 1
    endif
    return a:time
endfunction

" Julian day (always Gregorian calendar)
function! s:jd(year,mon,day)
    let y = a:year + 4800 - (a:mon <= 2)
    let m = a:mon + (a:mon <= 2 ? 9 : -3)
    let jul = a:day + (153*m+2)/5 + s:div(1461*y,4) - 32083
    return jul - s:div(y,100) + s:div(y,400) + 38
endfunction

function! s:gregorian(jd)
    let l = a:jd + 68569
    let n = s:div(4 * l, 146097)
    let l = l - s:div(146097 * n + 3, 4)
    let i = ( 4000 * ( l + 1 ) ) / 1461001
    let l = l - ( 1461 * i ) / 4 + 31
    let j = ( 80 * l ) / 2447
    let d = l - ( 2447 * j ) / 80
    let l = j / 11
    let m = j + 2 - ( 12 * l )
    let y = 100 * ( n - 49 ) + i + l
    return {'y':y,'b':m,'d':d}
endfunction

function! s:normalizetime(time)
    let a:time.y += s:div(a:time.b-1,12)
    let a:time.b = s:mod(a:time.b-1,12)+1
    let seconds = a:time.h * 3600 + a:time.m * 60 + a:time.s
    let a:time.s = s:mod(seconds,60)
    let a:time.m = s:mod(s:div(seconds,60),60)
    let a:time.h = s:mod(s:div(seconds,3600),24)
    if seconds != 0 || a:time.b != 1 || a:time.d != 1
        let day = s:gregorian(s:jd(a:time.y,a:time.b,a:time.d)+s:div(seconds,86400))
        return extend(a:time,day)
    else
        return a:time
    endif
endfunction

function! s:applymodifer(number,modifier,width)
    if a:modifier == '-'
        return substitute(a:number,'^0*','','')
    elseif a:modifier == '_'
        return printf('%'.a:width.'d',a:number)
    elseif a:modifier == '^'
        return toupper(a:number)
    else
        return printf('%0'.a:width.'s',a:number)
    endif
endfunction

function! s:modyear(y)
    return printf('%02d',s:mod(a:y,100))
endfunction

function! s:strftime(pattern,time)
    if type(a:time) == type({})
        let time = s:normalizetime(copy(a:time))
    else
        let time = s:normalizetime(s:initializetime({'y':1970,'s':a:time}))
    endif
    let time.w = s:mod(s:jd(time.y,time.b,time.d)+1,7)
    let time.p = time.h
    let expanded = ""
    let remaining = a:pattern
    while remaining != ""
        if remaining =~ '^%'
            let modifier = matchstr(remaining,'%\zs[-_0^]\=\ze.')
            let specifier = matchstr(remaining,'%[-_0^]\=\zs.')
            let remaining = matchstr(remaining,'%[-_0^]\=.\zs.*')
            if specifier == '%'
                let expanded .= '%'
            elseif has_key(s:strftime_items,specifier)
                let item = s:strftime_items[specifier]
                let number = time[item[1]]
                if type(item[4]) == type([])
                    let expanded .= s:applymodifer(item[4][number % len(item[4])],modifier,1)
                elseif type(item[4]) == type(function('tr'))
                    let expanded .= s:applymodifer(call(item[4],[number]),modifier,1)
                else
                    let expanded .= s:applymodifer(number,modifier,item[4])
                endif
            else
                let expanded .= '%'.modifier.specifier
            endif
        else
            let expanded .= matchstr(remaining,'[^%]*')
            let remaining = matchstr(remaining,'[^%]*\zs.*')
        endif
    endwhile
    return expanded
endfunction

" }}}1
" Time Handler {{{1

function! s:timestamp(utc,count)
    for handler in s:time_handlers
        let [start,end,string;caps] = s:findinline('\C'.join(handler.groups,''))
        if string != ""
            let format = substitute(handler.strftime,'\\\([1-9]\)','\=caps[submatch(1)-1]','g')
            if a:utc
                let newstring = s:strftime(format,localtime()+a:count*60*15)
            elseif a:count
                let newstring = s:strftime(format,localtime()-a:count*60*15)
            else
                let newstring = s:strftime(format,{
                            \ 'y': strftime('%Y'),
                            \ 'b': strftime('%m'),
                            \ 'd': strftime('%d'),
                            \ 'h': strftime('%H'),
                            \ 'm': strftime('%M'),
                            \ 's': strftime('%S')})
            endif
            call s:replaceinline(start,end,newstring)
            call setpos('.',[0,line('.'),start+strlen(newstring),0])
            silent! call repeat#set("\<Plug>SpeedDatingNow".(a:utc ? "UTC" : "Local"),a:count)
            return ""
        endif
    endfor
    let [start,end,string;caps] = s:findinline('-\=\<\d\+\>')
    if string != ""
        let newstring = localtime() + (a:utc ? 1 : -1) * a:count * 60*15
        call s:replaceinline(start,end,newstring)
        call setpos('.',[0,line('.'),start+strlen(newstring),0])
        silent! call repeat#set("\<Plug>SpeedDatingNow".(a:utc ? "UTC" : "Local"),a:count)
    endif
endfunction

function! s:dateincrement(string,offset,increment) dict
    let [start,end,string;caps] = s:match(a:string,'\C'.join(self.groups,''))
    let string = a:string
    let offset = a:offset
    let cursor_capture = 1
    let idx = 0
    while idx < len(self.groups)
        let partial_matchend = matchend(string,join(self.groups[0:idx],''))
        if partial_matchend > offset
            break
        endif
        let idx += 1
    endwhile
    while get(self.targets,idx,"") == " "
        let idx += 1
    endwhile
    while get(self.targets,idx," ") == " "
        let idx -= 1
    endwhile
    let partial_pattern = join(self.groups[0:idx],'')
    let char = self.targets[idx]
    let i = 0
    let time = {}
    for cap in caps
        if get(self.reader,i," ") !~ '^\s\=$'
            let time[self.reader[i]] = substitute(cap,'^\s*','','')
        endif
        let i += 1
    endfor
    call s:initializetime(time)
    let time[char] += a:increment
    let format = substitute(self.strftime,'\\\([1-9]\)','\=caps[submatch(1)-1]','g')
    let time_string = s:strftime(format,time)
    return [time_string, matchend(time_string,partial_pattern)]
endfunction

let s:strftime_items = {
            \ "a": ['d','w',s:ary2pat(s:days_abbr),   'weekday (abbreviation)',s:days_abbr],
            \ "A": ['d','w',s:ary2pat(s:days_full),   'weekday (full name)',s:days_full],
            \ "i": ['d','w',s:ary2pat(s:days_engl),   'weekday (English abbr)',s:days_engl],
            \ "b": ['b','b',s:ary2pat(s:months_abbr), 'month (abbreviation)',[""]+s:months_abbr],
            \ "B": ['b','b',s:ary2pat(s:months_full), 'month (full name)',[""]+s:months_full],
            \ "h": ['b','b',s:ary2pat(s:months_engl), 'month (English abbr)',[""]+s:months_engl],
            \ "d": ['d','d','[ 0-3]\=\d', 'day   (01-31)',2],
            \ "H": ['h','h','[ 0-2]\=\d', 'hour  (00-23)',2],
            \ "I": ['h','h','[ 0-2]\=\d', 'hour  (01-12)',['12', '01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11']],
            \ "m": ['b','b','[ 0-1]\=\d', 'month (01-12)',2],
            \ "M": ['m','m','[ 0-5]\=\d', 'minutes',2],
            \ "o": ['d','d','[ 0-3]\=\d\%(st\|nd\|rd\|th\)','day  (1st-31st)',s:function("s:ordinalize")],
            \ "P": ['h','p','[ap]m', 'am/pm',repeat(['am'],12) + repeat(['pm'],12)],
            \ "S": ['s','s','[ 0-5]\=\d', 'seconds',2],
            \ "v": ['y','y','[ivxlcdmn]\+','year (roman numerals)',s:function("s:arabic2roman")],
            \ "y": ['y','y','\d\d','year  (00-99)',s:function("s:modyear")],
            \ "Y": ['y','y','-\=\d\d\d\=\d\=','year',4]}

function! s:timeregexp() dict
    return join(self.groups,'')
endfunction

function! s:createtimehandler(format)
    let pattern = '^\%(%?\=\[.\{-\}\]\|%[-_0^]\=.\|[^%]*\)'
    let regexp = ['\%(\<\|-\@=\)']
    let reader = []
    let targets = [' ']
    let template = ""
    let default = ""
    let remaining = substitute(a:format,'\C%\@<!%p','%^P','g')
    let group = 0
    let usergroups = []
    let userdefaults = []
    while remaining != ""
        let fragment  = matchstr(remaining,pattern)
        let remaining = matchstr(remaining,pattern.'\zs.*')
        if fragment =~ '^%\*\W'
            let suffix = '*'
            let fragment = '%' . strpart(fragment,2)
        elseif fragment =~ '^%?\W'
            let suffix = '\='
            let fragment = '%' . strpart(fragment,2)
        else
            let suffix = ''
        endif
        let targets += [' ']
        if fragment =~ '^%' && has_key(s:strftime_items,matchstr(fragment,'.$'))
            let item = s:strftime_items[matchstr(fragment,'.$')]
            let modifier = matchstr(fragment,'^%\zs.\ze.$')
            let targets[-1] = item[0]
            let reader += [item[1]]
            if modifier == '^'
                let pat = substitute(item[2],'\C\\\@<![[:lower:]]','\u&','g')
            elseif modifier == '0'
                let pat = substitute(item[2],' \|-\@<!\\=','','g')
            else
                let pat = item[2]
            endif
            let regexp += ['\('.pat.'\)']
            let group += 1
            let template .= fragment
            let default .= fragment
        elseif fragment =~ '^%\[.*\]$'
            let reader += [' ']
            let regexp += ['\('.matchstr(fragment,'\[.*').suffix.'\)']
            let group += 1
            let usergroups += [group]
            let template .= "\\".group
            if suffix == ""
                let default .= strpart(fragment,2,1)
                let userdefaults += [strpart(fragment,2,1)]
            else
                let userdefaults += [""]
            endif
        elseif fragment =~ '^%\d'
            let regexp += ["\\".usergroups[strpart(fragment,1)-1]]
            let template .= regexp[-1]
            let default .= userdefaults[strpart(fragment,1)-1]
        elseif fragment == '%*'
            if len(regexp) == 1
                let regexp = []
                let targets = []
            else
                let regexp += ['\(.*\)']
            endif
        else
            let regexp += [fragment]
            let template .= fragment
            let default .= fragment
        endif
    endwhile
    if regexp[-1] == '\(.*\)'
        call remove(regexp,-1)
        call remove(targets,-1)
    else
        let regexp += ['\>']
    endif
    return {'source': a:format, 'strftime': template, 'groups': regexp, 'regexp': s:function('s:timeregexp'), 'reader': reader, 'targets': targets, 'default': default, 'increment': s:function('s:dateincrement')}
endfunction

function! s:comparecase(i1, i2)
    if a:i1 ==? a:i2
        return a:i1 ==# a:i2 ? 0 : a:i1 ># a:i2 ? 1 : -1
    else
        return tolower(a:i1) > tolower(a:i2) ? 1 : -1
    endif
endfunction

function! s:adddate(master,count,bang)
    if a:master == ""
        if a:bang && a:count
            silent! call remove(s:time_handlers,a:count - 1)
        elseif a:bang
            echo "SpeedDatingFormat             List defined formats"
            echo "SpeedDatingFormat!            This help"
            echo "SpeedDatingFormat %Y-%m-%d    Add a format"
            echo "1SpeedDatingFormat %Y-%m-%d   Add a format before first format"
            echo "SpeedDatingFormat! %Y-%m-%d   Remove a format"
            echo "1SpeedDatingFormat!           Remove first format"
            echo " "
            echo "Expansions:"
            for key in sort(keys(s:strftime_items),s:function("s:comparecase"))
                echo printf("%2s     %-25s %s",'%'.key,s:strftime_items[key][3],s:strftime('%'.key,localtime()))
            endfor
            echo '%0x    %x with mandatory leading zeros'
            echo '%_x    %x with spaces rather than leading zeros'
            echo '%-x    %x with no leading spaces or zeros'
            echo '%^x    %x in uppercase'
            echo '%*     at beginning/end, surpress \</\> respectively'
            echo '%[..]  any one character         \([..]\)'
            echo '%?[..] up to one character       \([..]\=\)'
            echo '%1     character from first collection match \1'
            echo " "
            echo "Examples:"
            echo 'SpeedDatingFormat %m%[/-]%d%1%Y    " American 12/25/2007'
            echo 'SpeedDatingFormat %d%[/-]%m%1%Y    " European 25/12/2007'
            echo " "
            echo "Define formats in ".s:install_dir."/after/plugin/speeddating.vim"
        elseif a:count
            echo get(s:time_handlers,a:count-1,{'source':''}).source
        else
            let i = 0
            for handler in s:time_handlers
                let i += 1
                echo printf("%3d %-32s %-32s",i,handler.source,s:strftime(handler.default,localtime()))
            endfor
        endif
    elseif a:bang
        call filter(s:time_handlers,'v:val.source != a:master')
    else
        let handler = s:createtimehandler(a:master)
        if a:count
            call insert(s:time_handlers,handler,a:count - 1)
        else
            let s:time_handlers += [handler]
        endif
    endif
endfunction

let s:time_handlers = []

command! -bar -bang -count=0 -nargs=? SpeedDatingFormat :call s:adddate(<q-args>,<count>,<bang>0)

" }}}1
" Default Formats {{{1

SpeedDatingFormat %a %b %d %H:%M:%S UTC %Y      " default date(1) format
SpeedDatingFormat %a %b %d %H:%M:%S %[A-Z]%[A-Z]T %Y
SpeedDatingFormat %i, %d %h %Y %H:%M:%S         " RFC822, sans timezone
SpeedDatingFormat %i, %h %d, %Y at %I:%M:%S%^P  " mutt default date format
SpeedDatingFormat %h %_d %H:%M:%S               " syslog
SpeedDatingFormat %Y-%m-%d%[ T_-]%H:%M:%S%?[Z]  " SQL, etc.
SpeedDatingFormat %Y-%m-%d
SpeedDatingFormat %-I:%M:%S%?[ ]%^P
SpeedDatingFormat %-I:%M%?[ ]%^P
SpeedDatingFormat %-I%?[ ]%^P
SpeedDatingFormat %H:%M:%S
SpeedDatingFormat %B %o, %Y
SpeedDatingFormat %d%[-/ ]%b%1%y
SpeedDatingFormat %d%[-/ ]%b%1%Y                " These three are common in the
SpeedDatingFormat %Y %b %d                      " 'Last Change:' headers of
SpeedDatingFormat %b %d, %Y                     " Vim runtime files
SpeedDatingFormat %^v
SpeedDatingFormat %v

" }}}1
" Maps {{{1

nnoremap <silent> <Plug>SpeedDatingUp   :<C-U>call <SID>increment(v:count1)<CR>
nnoremap <silent> <Plug>SpeedDatingDown :<C-U>call <SID>increment(-v:count1)<CR>
vnoremap <silent> <Plug>SpeedDatingUp   :<C-U>call <SID>incrementvisual(v:count1)<CR>
vnoremap <silent> <Plug>SpeedDatingDown :<C-U>call <SID>incrementvisual(-v:count1)<CR>
nnoremap <silent> <Plug>SpeedDatingNowLocal :<C-U>call <SID>timestamp(0,v:count)<CR>
nnoremap <silent> <Plug>SpeedDatingNowUTC   :<C-U>call <SID>timestamp(1,v:count)<CR>

if !exists("g:speeddating_no_mappings") || !g:speeddating_no_mappings
    nmap  <C-A>     <Plug>SpeedDatingUp
    nmap  <C-X>     <Plug>SpeedDatingDown
    xmap  <C-A>     <Plug>SpeedDatingUp
    xmap  <C-X>     <Plug>SpeedDatingDown
    nmap d<C-A>     <Plug>SpeedDatingNowUTC
    nmap d<C-X>     <Plug>SpeedDatingNowLocal
endif

" }}}1

let &cpo = s:cpo_save

" vim:set et sw=4 sts=4:
