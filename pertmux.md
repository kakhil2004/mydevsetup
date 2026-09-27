## TMUX

Install tmux whatever version


POST 2.1
```
bind m \
    set -g mouse on \;\
    display 'Mouse: ON'

bind M \
    set -g mouse off \;\
    display 'Mouse: OFF'    
```

PRE 2.1
```
bind m \
    set -g mode-mouse on \;\
    display 'Mouse: ON'

bind M \
    set -g mode-mouse off \;\
    display 'Mouse: OFF'
```

My personal TMUX wrapper, make a ~/.kilhak_zsh_functions.zsh and then add also to source thing so it opens in every termina

```
# pertmux: persistent tmux made easy.
# Usage:
#   pertmux            list sessions (naming is enforced; use a name to create)
#   pertmux <name>     attach-or-create the named session (never errors)
#   pertmux <index>    attach to the session at that index in `pertmux` list
#   pertmux ls         list sessions
#   pertmux kill <n>   kill the named session
#   pertmux killall    kill the tmux server (all sessions)
# Detach (leave running) with: Ctrl-b d
pertmux() {
  case "$1" in
    ""|ls)
      # numbered list so `pertmux <index>` lines up with what's shown
      local -a sessions
      sessions=(${(f)"$(tmux ls -F '#{session_name}' 2>/dev/null)"})
      if (( ${#sessions} == 0 )); then
        echo "no sessions (create one with: pertmux <name>)"
      else
        local i
        for i in {1..${#sessions}}; do
          printf '%d\t%s\n' $((i - 1)) "${sessions[$i]}"
        done
      fi
      ;;
    kill)    tmux kill-session -t "$2" ;;
    killall) tmux kill-server ;;
    <->)     # numeric index into the current session list
      local -a sessions
      sessions=(${(f)"$(tmux ls -F '#{session_name}' 2>/dev/null)"})
      if [[ -n "${sessions[$(($1 + 1))]}" ]]; then
        tmux new-session -A -s "${sessions[$(($1 + 1))]}"
      else
        echo "pertmux: no session at index $1" >&2
        tmux ls
      fi
      ;;
    *)       tmux new-session -A -s "$1" ;;
  esac
}

# Tab-completion for pertmux: subcommands + live session names.
_pertmux() {
  local -a subcmds sessions
  subcmds=(ls kill killall)
  sessions=(${(f)"$(tmux ls -F '#{session_name}' 2>/dev/null)"})
  if (( CURRENT == 2 )); then
    _describe 'subcommand' subcmds
    _describe 'session' sessions
  elif (( CURRENT == 3 )) && [[ "$words[2]" == kill ]]; then
    _describe 'session' sessions
  fi
}
compdef _pertmux pertmux
```
