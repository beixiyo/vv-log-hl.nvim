" Vim syntax file
" Language:   Generic log files
" Based on:   fei6409/log-highlight.nvim (MIT)

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Symbols
syn match VVLogSymbol         display     '[!@#$%^&*;:?]'

" Separators
syn match VVLogSeparatorLine  display     '-\{3,}\|=\{3,}\|#\{3,}\|\*\{3,}'

" Strings
syn region VVLogString        start=/"/  end=/"/  end=/$/  skip=/\\./  contains=@VVLogLvs
syn region VVLogString        start=/`/  end=/`/  end=/$/  skip=/\\./  contains=@VVLogLvs
syn region VVLogString        start=/\(s\)\@<!'\(s \|t \)\@!/  end=/'/  end=/$/  skip=/\\./  contains=@VVLogLvs

" Numbers
syn match VVLogNumber         display     '\<\d\+\>'
syn match VVLogNumberFloat    display     '\<\d\+\.\d\+\([eE][+-]\?\d\+\)\?\>'
syn match VVLogNumberHex      display     '\<0[xX]\x\+\>'
syn match VVLogNumberHex      display     '\<\x\{4,}\>'

" Constants
syn keyword VVLogBool    TRUE True true FALSE False false
syn keyword VVLogNull    NULL Null null

" Date & Time
syn match VVLogDate       display     '\<\d\{2}[-\/]\d\{2}\>'
syn match VVLogDate       display     '\<\d\{4}[-\/]\d\{2}[-\/]\d\{2}\>'
syn match VVLogDate       display     '\<\d\{2}[-\/]\d\{2}[-\/]\d\{4}\>'
syn match VVLogDate       display     '\<\d\{4}-\d\{2}-\d\{2}T'
syn match VVLogDate       display     '\<\a\{3} \d\{1,2}\(,\? \d\{4}\)\?\>'
syn match VVLogDate       display     '\<\d\{1,2}[- ]\a\{3}[- ]\d\{4}\>'
syn keyword VVLogWeekdayStr   Mon Tue Wed Thu Fri Sat Sun
syn match VVLogTime       display     '\d\{2}:\d\{2}:\d\{2}\(\.\d\{2,6}\)\?'  skipwhite  nextgroup=VVLogTimeZone,VVLogTimeAMPM
syn match VVLogTimeAMPM   display     '\cAM\|\cPM\>'  contained
syn match VVLogTimeZone   display     'Z\|[+-]\d\{2}:\d\{2}\|\a\{3}\>'  contained

" Duration
syn match VVLogDuration   display     '\(\(\(\d\+d\)\?\d\+h\)\?\d\+m\)\?\d\+\(\.\d\+\)\?[mun]\?s\>'

" Objects
syn match VVLogUrl        display     '\<https\?:\/\/\S\+'
syn match VVLogIPv4       display     '\<\d\{1,3}\(\.\d\{1,3}\)\{3}\(\/\d\+\)\?\>'
syn match VVLogUUID       display     '\<\x\{8}-\x\{4}-\x\{4}-\x\{4}-\x\{12}\>'
syn match VVLogPath       display     '\(^\|\s\|=\)\zs\(\.\{0,2}\|\~\)\/[^ \t\n\r]\+\ze'

" Log Levels (case-insensitive)
syn case ignore
syn keyword VVLogLvFatal      FATAL
syn keyword VVLogLvEmergency  EMERG EMERGENCY
syn keyword VVLogLvAlert      ALERT
syn keyword VVLogLvCritical   CRIT CRITICAL
syn keyword VVLogLvError      ERROR ERR ERRORS
syn keyword VVLogLvFail       FAIL FAILED FAILURE
syn keyword VVLogLvWarning    WARN WARNING
syn keyword VVLogLvNotice     NOTICE
syn keyword VVLogLvInfo       INFO
syn keyword VVLogLvDebug      DEBUG DBG
syn keyword VVLogLvTrace      TRACE
syn keyword VVLogLvVerbose    VERBOSE
syn keyword VVLogLvPass       PASS PASSED
syn keyword VVLogLvSuccess    SUCCESS DONE OK

" Composite log levels e.g. *_INFO
syn match VVLogLvFatal        display '\<\w\+_FATAL\>'
syn match VVLogLvCritical     display '\<\w\+_CRIT\(ICAL\)\?\>'
syn match VVLogLvError        display '\<\w\+_ERR\(OR\)\?\>'
syn match VVLogLvWarning      display '\<\w\+_WARN\(ING\)\?\>'
syn match VVLogLvInfo         display '\<\w\+_INFO\>'
syn match VVLogLvDebug        display '\<\w\+_DEBUG\>'
syn match VVLogLvTrace        display '\<\w\+_TRACE\>'
syn case match

syn cluster VVLogLvs contains=VVLogLvFatal,VVLogLvEmergency,VVLogLvAlert,VVLogLvCritical,VVLogLvError,VVLogLvFail,VVLogLvWarning,VVLogLvNotice,VVLogLvInfo,VVLogLvDebug,VVLogLvTrace,VVLogLvVerbose,VVLogLvPass,VVLogLvSuccess

" Highlight Links
hi def link VVLogNumber           Number
hi def link VVLogNumberFloat      Float
hi def link VVLogNumberHex        Number
hi def link VVLogSymbol           Delimiter
hi def link VVLogSeparatorLine    Comment
hi def link VVLogBool             Boolean
hi def link VVLogNull             Constant
hi def link VVLogString           String
hi def link VVLogDate             Type
hi def link VVLogWeekdayStr       Type
hi def link VVLogTime             Operator
hi def link VVLogTimeAMPM         Operator
hi def link VVLogTimeZone         Operator
hi def link VVLogDuration         Operator
hi def link VVLogUrl              Underlined
hi def link VVLogIPv4             Special
hi def link VVLogUUID             Label
hi def link VVLogPath             Directory

" Log level and cap colors are set in Lua (survives colorscheme changes)

" Treesitter highlight groups
if has('nvim-0.10')
  hi def link VVLogUrl            @markup.link.url
endif

let b:current_syntax = "log"
let &cpo = s:cpo_save
unlet s:cpo_save
