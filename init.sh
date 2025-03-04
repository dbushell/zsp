##############################
#             o              #
#      o      |              #
#  o-o   o--o O-o   oo  o-o  #
#   /  | |  | |  | | |  |    #
#  o-o | o--O o-o  o-o- o    #
#           |                #
#        o--o                #
##############################

# ZSH init script adapted from Starship (ISC license)
# https://github.com/starship/starship/blob/master/src/init/starship.zsh

zmodload zsh/datetime
zmodload zsh/mathfunc

__zigbar_get_time() {
  (( ZIGBAR_CAPTURED_TIME = int(rint(EPOCHREALTIME * 1000)) ))
}

prompt_zigbar_precmd() {
  if (( ${+ZIGBAR_START_TIME} )); then
    __zigbar_get_time && (( ZIGBAR_DURATION = ZIGBAR_CAPTURED_TIME - ZIGBAR_START_TIME ))
    unset ZIGBAR_START_TIME
  else
    unset ZIGBAR_DURATION
  fi
}

prompt_zigbar_preexec() {
  __zigbar_get_time && ZIGBAR_START_TIME=$ZIGBAR_CAPTURED_TIME
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd prompt_zigbar_precmd
add-zsh-hook preexec prompt_zigbar_preexec

setopt promptsubst

PROMPT='$('${0:a:h}'/zig-out/aarch64-macos/zigbar prompt --columns="$COLUMNS" --duration="${ZIGBAR_DURATION:-}")'
