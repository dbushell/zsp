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

__zsp_get_time() {
  (( ZSP_CAPTURED_TIME = int(rint(EPOCHREALTIME * 1000)) ))
}

prompt_zsp_precmd() {
  if (( ${+ZSP_START_TIME} )); then
    __zsp_get_time && (( ZSP_DURATION = ZSP_CAPTURED_TIME - ZSP_START_TIME ))
    unset ZSP_START_TIME
  else
    unset ZSP_DURATION
  fi
}

prompt_zsp_preexec() {
  __zsp_get_time && ZSP_START_TIME=$ZSP_CAPTURED_TIME
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd prompt_zsp_precmd
add-zsh-hook preexec prompt_zsp_preexec

setopt promptsubst

PROMPT='$(zsp prompt --columns="$COLUMNS" --duration="${ZSP_DURATION:-}")'
