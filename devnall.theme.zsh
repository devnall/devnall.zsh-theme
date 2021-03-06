# devnall.zsh-theme
#
# Reference:
# git:
# %b => current branch
# %a => current action
# prompt:
# %F => color dict
# %f => reset color
# %~ => current path
# %* => time
# %n => username
# %m => short hostname
# %(?..) => prompt conditional - %(condition.true.false)
# terminal codes:
# \e7   => save cursor position
# \e[2A => move cursor 2 lines up
# \e[1G => go to position 1 in terminal
# \e8   => restore cursor position
# \e[K  => clears everything after the cursor on current line
# \e[2K => clear everything on current line

# My color variables
eval my_gray='$FG[237]'
eval my_orange='$FG[214]'

# Convert seconds to human-readable time
# e.g. 165392 => 1d 21h 56m 32s
# https://github.com/sindresorhus/pretty-time-zsh
prompt_human_time_to_var() {
  local human=" " total_seconds=$1 var=$2
  local days=$(( total_seconds / 60 /60 / 24 ))
  local hours=$(( total_seconds / 60 / 60 % 24 ))
  local minutes=$(( total_seconds / 60 % 60 ))
  local seconds=$(( total_seconds % 60 ))
  (( days > 0 )) && human+="${days}d "
  (( hours > 0 )) && human+="${hours}h "
  (( minutes > 0 )) && human+="${minutes}m "
  human+="${seconds}s"

  # store human-readable time in variable as specified by caller
  typeset -g "${var}"="${human}"
}

# stores (into prompt_cmd_exec_time) the exec time of the last command if set threshold exceeded
# (currently 5 secs, change in CMD_MAX_EXEC_TIME:=)
prompt_check_cmd_exec_time() {
  integer elapsed
  (( elapsed = EPOCHSECONDS - ${prompt_cmd_timestamp:-$EPOCHSECONDS} ))
  prompt_cmd_exec_time=
  (( elapsed > ${CMD_MAX_EXEC_TIME:=5} )) && {
    prompt_human_time_to_var $elapsed "prompt_cmd_exec_time"
  }
}

prompt_clear_screen() {
  # enable output to terminal
  zle -I
  # clear screen and move cursor to (0,0)
  print -n '\e[2J\e[0;0H'
  # print preprompt
  prompt_preprompt_render precmd
}

prompt_git_check() {
  # check if in a git repo
  command git rev-parse --is-inside-work-tree &>/dev/null || return
  if [[ $? -eq 1 ]]; then
    exit 0
  else
    echo "%F{39}%f"
  fi
}

prompt_git_dirty() {
  # check if in a git repo
  command git rev-parse --in-inside-work-tree &>/dev/null || return
  # check if repo is dirty
  command git diff --quiet --ignore-submodules HEAD &>/dev/null;
  if [[ $? -eq 1 ]]; then
    echo "F${my_orange}±%f"
  else
    echo "%F{green}✔%f"
  fi
}

prompt_check_git_arrows() {
  # reset git arrows
  prompt_git_arrows=

  # check if there is an upstream configured for this branch
  command git rev-parse --abbrev-ref @'{u}' &>/dev/null || return

  local arrow_status
  # check git left and right arrow_status
  arrow_status="$(command git rev-list --left-right --count HEAD...@'{u}' 2>/dev/null)"
  # exit if the command fails
  (( !$? )) || return

  # left and right are tab-separated, split on tab and store as array
  arrow_status=(${(ps:\t:)arrow_status})
  local arrows left=${arrow_status[1]} right=${arrow_status[2]}

#  (( ${right:-0} > 0 )) && arrows+="${GIT_DOWN_ARROW:-⇣}"
#  (( ${left:-0} > 0 )) && arrows+="${GIT_UP_ARROW:-⇡}"
  (( ${right:-0} > 0 )) && arrows+="%F${my_orange}${GIT_DOWN_ARROW:-⬇}%f"
  (( ${left:-0} > 0 )) && arrows+="%F{red}${GIT_UP_ARROW:-⬆}%f"

  [[ -n $arrows ]] && prompt_git_arrows=" ${arrows}"
}

prompt_background_job() {
  local bgjob
  bgjob=$(jobs 2>/dev/null | tail -n 1)
  if [[ $bgjob == "" ]]; then
    echo ""
  else
    echo "%{$FG[208]%}✱%f"
  fi
}

prompt_set_title() {
  # emacs doesn't support setting the title
  (( ${EMACS} )) && return

  # tell the terminal we're setting the title
  print -n '\e]0;'
  # show hostname if connected via SSH
  [[ -n $SSH_CONNECTION ]] && print -Pn '(%m) '
  case $1 in
    expand-prompt)
      print -Pn $2;;
    ignore-escape)
      print -rn $2;;
  esac
  # end set title
  print -n '\a'
}

prompt_preexec() {
  # attempt to detect and prevent prompt_async_git_fetch from interfering with
  # user-initiated git or hub fetch
  [[ $2 =~ (git|hub)\ .*(pull|fetch) ]] && async_flush_jobs 'prompt'

  prompt_cmd_timestamp=$EPOCHSECONDS

  # shows the current dir and executed commands in the title while a process is active
  prompt_set_title 'ignore-escape' "$PWD:t: $2"
}

# string length ignoring ansi escapes
prompt_string_length_to_var() {
  local str=$1 var=$2 length
  # perform expansion on str and check length
  length=$(( ${#${(S%%)str//(\%([KF1]|)\{*\}|\%[Bbkf])}} ))

	# store string length in variable as specified by caller
	typeset -g "${var}"="${length}"
}

prompt_preprompt_render() {
	# store the current prompt_subst setting so that it can be restored later
	local prompt_subst_status=$options[prompt_subst]

	# make sure prompt_subst is unset to prevent parameter expansion in preprompt
	#setopt local_options no_prompt_subst
	setopt local_options no_prompt_subst

	#check that no command is currently running, the preprompt will otherwise be
	# rendered in the wrong place
	[[ -n ${prompt_cmd_timestamp+x} && "$1" != "precmd" ]] && return

	# set color for git branch/dirty status, change color if dirty check is delayed
	local git_color=246
	[[ -n ${prompt_git_last_dirty_check_timestamp+x} ]] && git_color=red

	# construct preprompt beginning with path
  local preprompt=""
  preprompt+="%F{blue}${prompt_git_check}%f"
  preprompt+="%F{blue}%~%f"
  # git info
  preprompt+="%F{$git_color}${vcs_info_msg_0_}${prompt_git_dirty}%f"
  # git pull/push arrows
  preprompt+="${prompt_git_arrows}"
  # username and machine (if applicable)
  preprompt+=$prompt_username
  # execution time
  preprompt+="%F${my_orange}${prompt_cmd_exec_time}%f"

  # make sure prompt_last_preprompt is a global array
  typeset -g -a prompt_last_preprompt

  # if executing through precmd, don't perform fancy terminal editing
  if [[ "$1" == "precmd" ]]; then
    print -P "\n${preprompt}"
  else
    # only redraw if the expanded preprompt has changed
    [[ "${prompt_last_preprompt[2]}" != "${(S%%)preprompt}" ]] || return

    # calculate length of preprompt and store locally in preprompt_length
    integer preprompt_length lines
    prompt_string_length_to_var "${preprompt}" "preprompt_length"

    # calculate number of preprompt lines for redraw purposes
    (( lines = ( preprompt_length - 1 ) / COLUMNS +1 ))

    # calculate previous preprompt lines to figure out how the new preprompt should behave
    integer last_preprompt_length last_lines
    prompt_string_length_to_var "${prompt_last_preprompt[1]}" "last_preprompt_length"
    (( last_lines = ( last_preprompt_length - 1 ) / COLUMNS +1 ))

    # clr_prev_preprompt erases visual artifacts from previous preprompt
    local clr_prev_preprompt
    if (( last_lines > lines )); then
      # move cursor up by last_lines, clear the line, and move it down by 1 line
      clr_prev_preprompt="\e[${last_lines}A\e[2K\e[1B"
      while (( last_lines - lines > 1 )); do
        # clear the line and move cursor down by one
        clr_prev_preprompt+='\e[2K\e[1B'
        (( last_lines-- ))
      done

      # move cursor into correct position for preprompt update
      clr_prev_preprompt+="\e[${lines}B"

    # create more space for preprompt if new preprompt has more lines than last
    elif (( last_lines < lines )); then
      # move cursor using newlines because ansi cursor movement can't push the cursor beyong the last line
      printf $'\n'%.0s {1..$(( lines - last_lines ))}
    fi

    # disable clearing of line if last char of preprompt is last column of terminal
    local clr='\e[K'
    (( COLUMNS * lines == preprompt_length )) && clr=

    # modify previous preprompt
    print -Pn "${clr_prev_preprompt}\e[${lines}A\e[${COLUMNS}D${preprompt}${clr}\n"

    if [[ $prompt_subst_status = 'on' ]]; then
      # reenable prompt_subst for expansion on PS1
      setopt prompt_subst
    fi

    # redraw prompt (also resets cursor position)
    zle && zle .reset-prompt
  fi

  # store both unexpanded and expanded preprompt for comparison
  prompt_last_preprompt=("$preprompt" "${(S%%)preprompt}")
}

prompt_precmd() {
  # check exec time and store in a var
  prompt_check_cmd_exec_time

  # by making sure that prompt_cmd_timestamp is defined here, the async funcs are prevented
  # from interfering with initial prompt rendering
  prompt_cmd_timestamp=

  # check for git arrows
  prompt_check_git_arrows

  # show the full path in the title
  prompt_set_title 'expand-prompt' '%~'

  # get vcs info
  vcs_info

  # perform async git dirty check and fetch
  prompt_async_tasks

  # print the preprompt
  prompt_preprompt_render "precmd"

  # remove the prompt_cmd_timestamp, indicating that precmd has completed
  unset prompt_cmd_timestamp
}

# fastest possible way to check if repo is dirty
prompt_asynch_git_dirty() {
  local untracked_dirty=$1; shift

  # use cd -q to avoid side effects of changing directory, e.g. chpwd hooks
  builtin cd -q "$*"

  if [[ "$untracked_dirty" == "0" ]]; then
    command git diff --no-ext-diff --quiet --exit-code
  else
    test -z "$(command git status --porcelain --ignore-submodules --unormal)"
  fi

  (( $? )) && echo "*"
}

prompt_async_git_fetch() {
  # use cd -q to avoid side effects of changing directory, e.g. chpwd hooks
  builtin cd -q "$*"

  # set GIT_TERMINAL_PROMPT=0 to disable auth prompting for git fetch (git 2.3+)
  GIT_TERMINAL_PROMPT=0 command git -c gc.auto=0 fetch
}

prompt_async_tasks() {
  # initialize async worker
  ((!${prompt_async_init:-0})) && {
    async_start_worker "prompt" -u -n
    async_register_callback "prompt" prompt_async_callback
    prompt_async_init=1
  }

  # store working_tree without the "x" prefix
  local working_tree="${vcs_info_msg_1_#x}"

  # check if the working tree changed (prompt_current_working_tree prefixed by "x")
  if [[ ${prompt_current_working_tree#x} != $working_tree ]]; then
    # stop any running async jobs
    async_flush_jobs "prompt"

    #reset git preprompt variables, switching working tree
    unset prompt_git_dirty
    unset prompt_git_last_dirty_check_timestamp

    # set the new working tree and prefix with "x" to prevent the creation of a named
    # path by AUTO_NAME_DIRS
    prompt_current_working_tree="x${working_tree}"
  fi

  # only perform tasks inside git working tree
  [[ -n $working_tree ]] || return

  # do not perform git fetch if it is disabled or working_tree == HOME
  if (( ${GIT_PULL:-1} )) && [[ $working_tree != $HOME ]]; then
    # tell worker to git fetch
    async_job "prompt" prompt_async_git_fetch "${working_tree}"
  fi

  # if dirty checking is sufficiently fast, tell worker to check it again or wait for timeout
  integer time_since_last_dirty_check=$(( EPOCHSECONDS - ${prompt_git_last_dirty_check_timestamp:-0} ))
  if (( time_since_last_dirty_check > ${GIT_DELAY_DIRTY_CHECK:-1800} )); then
    unset prompt_git_last_dirty_check_timestamp
    # check if there is anything to pull
    async_job "prompt" prompt_async_git_dirty "${GIT_UNTRACKED_DIRTY:-1}" "${working_tree}"
  fi
}

prompt_async_callback() {
  local job=$1
  local output=$3
  local exec_time=$4

  case "${job}" in
    prompt_async_git_dirty)
      prompt_git_dirty=$output
      prompt_preprompt_render

      # when prompt_git_last_dirty_check_timestamp is set, the git info is displayed in
      # a different color. To distinguish between "fresh" and "cached" result, the preprompt
      # is rendered before setting this variable. Thus, only upon next rendering of the
      # preprompt will the result appear in a different color
      (( $exec_time > 2 )) && prompt_git_last_dirty_check_timestamp=$EPOCHSECONDS
      ;;
    prompt_async_git_fetch)
      prompt_check_git_arrows
      prompt_preprompt_render
      ;;
  esac
}

prompt_setup() {
  # prevent % from appearing if output doesn't end with newline
  export PROMPT_EOL_MARK=''

  prompt_opts=(subst percent)

  zmodload zsh/datetime
  zmodload zsh/zle
  zmodload zsh/parameter

  autoload -Uz add-zsh-hook
  autoload -Uz vcs_info
  autoload -Uz async && async

  add-zsh-hook precmd prompt_precmd
  add-zsh-hook preexec prompt_preexec

  zstyle ':vcs_info:*' enable git
  zstyle ':vcs_info:*' use-simple true
  # only export two msg variables from vcs_info
  zstyle ':vcs_info:*' max-exports 2
  zstyle ':vcs_info:git*' formats ' %b' 'x%R'
  zstyle ':vcs_info:git*' actionformats ' %b|%a' 'x%R'

  # if user hasn't registered a custom zle widget for clear-screen, override
  # the builtin one so the preprompt is displayed correctly when ^L is given
  if [[ $widgets[clear-screen] == 'builtin' ]]; then
    zle -N clear-screen prompt_clear_screen
  fi

  # show username@host if logged in via SSH
  [[ "$SSH_CONNECTION" != '' ]] && prompt_username=' %F{242}%n@%m%f'

  # show username@host if root, with username in white
  [[ $UID -eq 0 ]] && prompt_username=' %F{white}%n%f%F{242}@%m%f'

  # prompt turns red if the previous command didn't exit 0
  PROMPT="%(?.%F{magenta}.%F{red})${PROMPT_SYMBOL:-❯}%f "
}

prompt_setup "$@"

## PURE END

## LEGACY START

# Make git info available to prompt
#autoload colors && colors

# color vars
#eval my_gray='$FG[237]'
#eval my_orange='$FG[214]'

# Functions to build git-aware prompt(s)
#git_check() {
#  command git rev-parse --is-inside-work-tree &>/dev/null || return
#  if [[ $? -eq 1 ]]; then
#    exit 0
#  else
#    echo "%F{39}%f"
#  fi
#}
#
#git_dirty() {
#  # check to see if we're in a git repo
#  command git rev-parse --is-inside-work-tree &>/dev/null || return
#  # check to see if it's dirty
#  command git diff --quiet --ignore-submodules HEAD &>/dev/null;
#  if [[ $? -eq 1 ]]; then
##    echo "%F{red}✗%f"
#    echo "%F${my_orange}±%f"
#  else
#    echo "%F{green}✔%f"
#  fi
#}
#
## Get the status of the current branch and its remote
## If there are changes upstream, display a ⇣
## If there are changes that have been committed but not yet pushed, display a ⇡
#git_arrows() {
#  # do nothing if there is no upstream configured
#  command git rev-parse --abbrev-ref @'{u}' &>/dev/null || return
#
#  local arrows=""
#  local status
#  arrow_status="$(command git rev-list --left-right --count HEAD...@'{u}' 2>/dev/null)"
#
#  # do nothing if the command failed
#  (( !$? )) || return
#
#  # split on tabs
#  arrow_status=(${(ps:\t:)arrow_status})
#  local left=${arrow_status[1]} right=${arrow_status[2]}
#
#  (( ${right:-0} > 0 )) && arrows+="%F{red}⬇%f"
##  (( ${left:-0} > 0 )) && arrows+="%F{046}⇡%f"
#  (( ${left:-0} > 0 )) && arrows+="%F${my_orange}⬆%f"
##  (( ${left:-0} > 0 )) && arrows+="%F{208}⇡%f"
#
#  echo $arrows
#}
#
## If there is a job in the background, display a ✱
#suspended_jobs() {
#  local sj
#  sj=$(jobs 2>/dev/null | tail -n 1)
#  if [[ $sj == "" ]]; then
#    echo ""
#  else
#    echo "%{$FG[208]%}✱%f"
#  fi
#}
#
#if [ $UID -eq 0 ]; then NCOLOR="red"; else NCOLOR="green"; fi
#local return_code="%(?..%{$fg[red]%}%? ↵%{$reset_color%})"
#
#if [ "${whoami}" = "root" ]
#then CARETCOLOR="red"
#else CARETCOLOR="blue"
#fi
#
#



## precmd() {
##  vcs_info
###  print -P '\n`git_check`%F{39}%~ `git_dirty`%F{246}$vcs_info_msg_0_%f `git_arrows` `suspended_jobs`'
##  print -P '\n`git_check``git_arrows` %F{39}%~  %F{246}$vcs_info_msg_0_%f `git_dirty`'
##}
##
##export PROMPT='`suspended_jobs`%(?.%F{10}.%F{10})❯%f '
###export RPROMPT='`git_dirty`%F{246}$vcs_info_msg_0_%f `git_arrows` `suspended_jobs`'
##export RPROMPT=''
