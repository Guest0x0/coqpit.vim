" ==============================================================
" ------------------------ CoqTopDriver ------------------------
" ==============================================================
" LastUpdate : 2019/12/13

" + support for Coq 8.7


let s:CoqTopDriver = {}

function! s:CoqTopDriver.new()
  call self.restart()
  return self
endfunction

" restart {{{
function! s:CoqTopDriver.restart()
  let self.states = []
  silent! unlet self.root_state
  silent! unlet self.state_id

  let self.sentenceQueue = []
  let self.waiting = 0

  let coqtop_cmd = [
  \  'coqtop',
  \  '-ideslave',
  \  '-main-channel',
  \  'stdfds',
  \  '-async-proofs',
  \  'on'
  \  ]

  let job_options = {}

  let job_options.in_mode = 'raw'
  let job_options.out_mode = 'raw'
  let job_options.err_mode = 'nl'

  let job_options.out_cb = self._out_cb
  let job_options.err_cb = self._err_cb

  let self.job = job_start(coqtop_cmd, job_options)
  let self.channel = job_getchannel(self.job)

  call self._init()
endfunction " }}}

" out callback {{{
function! s:CoqTopDriver._out_cb(channel, msg)
  echom a:msg

  let self.waiting = 0

  let xml = webapi#xml#parse(a:msg)
  let g:gxml = xml  " for debug

  call self.cb(xml)
endfunction
" }}}

function! s:CoqTopDriver._initiated()
  return exists("self.root_state")
endfunction

function! s:CoqTopDriver._process_queue()
  if !self._initiated() || self.waiting
    return
  endif
  if len(self.sentenceQueue) > 0
    let front = remove(self.sentenceQueue, 0)
    call self.sendSentence(front)
  endif
endfunction

function! s:CoqTopDriver._err_cb(channel, msg)
  echoerr a:msg
endfunction

function! s:CoqTopDriver.running()
  return exists("self.job") && exists("self.channel")
endfunction

function! s:CoqTopDriver.kill()
  if self.running()
    call job_stop(self.job, "term")
    unlet self.job
  endif
endfunction

function! s:CoqTopDriver._call(msg, cb)
  if self.waiting
    return
  endif
  if self.running()
    let self.waiting = 1
    let self.cb = a:cb
    call ch_sendraw(self.channel, a:msg)
  endif
endfunction

function! s:CoqTopDriver.currentState()
  if len(self.states) == 0
    return self.root_state
  else
    return self.state_id
  endif
endfunction


"  send Init < init > {{{
function! s:CoqTopDriver._init()
  call self._call(
    \ '<call val="Init"><option val="none"/></call>'
    \ , self._sendInitCallback)
endfunction
function! s:CoqTopDriver._sendInitCallback(xml)
  let self.state_id = a:xml.find("state_id").attr.val
  let self.root_state = self.state_id
  call self._process_queue()
endfunction
" }}}


" send Add < send sentence > {{{
function! s:CoqTopDriver.sendSentence(sentence)
  call self._call('
  \ <call val="Add">
  \   <pair>
  \     <pair>
  \       ' . s:createElement("string", {}, sentence) . '
  \       <int>-1</int>
  \     </pair>
  \   <pair>
  \   ' . s:createElement("state_id", {"val": self.currentState()}) . '
  \   <bool val="false"/>
  \   </pair>
  \   </pair>
  \ </call>
  \', self._sendAddCallback)
endfunction
function! s:CoqTopDriver._sendAddCallback(xml)
  if exists("self.info_cb")
    " TODO
    " call self.info_cb(level, msg)
  endif
endfunction
" }}}


" send Goal < update Goals > {{{
function! s:CoqTopDriver.goals()
  call self._call(
    \ '<call val="Goal"><unit /></call>'
    \ , self._sendGoalCallback)
endfunction
function! s:CoqTopDriver._sendGoalCallback(xml)
endfunction
" }}}


function! s:CoqTopDriver.queueSentence(sentence)
  call add(self.sentenceQueue, sentence)
  call self._process_queue()
endfunction


" set callback function for Infos
" cb : (message_level, message) => any
" - message_levels
"   TODO
"   - 0 : debug
"   - 1 : info
"   - 2 : warning
"   - 3 : error
"   - 4 : fatal
function! s:CoqTopDriver.setInfoCallback(info_cb)
  self.info_cb = a:info_cb
endfunction


" set callback function for Goals
" cb : (xml) => any
function! s:CoqTopDriver.setGoalCallback(goal_cb)
  self.goal_cb = a:goal_cb
endfunction


" internal functions

function! s:createElement(name, attr, ...)
  let element = webapi#xml#createElement("string")
  element.attr = a:attr
  if a:0
    element.value(a:000[0])
  endif
  return element
endfunction


" Export

function! coquille#coqtop#makeInstance()
  return s:CoqTopDriver.new()
endfunction

function! coquille#coqtop#isExecutable()
  " TODO
  return 1
endfunction

function! coquille#coqtop#getVersion()
  " TODO
  return "1.0.0"
endfunction

