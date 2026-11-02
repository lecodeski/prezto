#
# fzf-tab preview for command-position candidates — sourced by the bare preview shell.
# $1: snapshot dir, $2: snapshot pid — both written by the fzf-preview style in init.zsh.
#

source $1/snapshot.$2
case $group in
  ('[alias]'|'[regular alias]')
    print -r -- $word=${(q-)a[$word]} ;;
  ('[shell function]')
    source $1/functions.$2
    if [[ $f[$word] == 'builtin autoload -X'* ]]; then
      local -a src=(${^p}/$word(N))
      bat --color=always --style=plain --language=zsh -- $src[1]
    else
      print -rl -- "$word () {" $f[$word] '}' | bat --color=always --style=plain --language=zsh
    fi ;;
  ('[parameter]')
    setopt extended_glob
    local -a line=(${(M)${(f)"$(<$1/parameters.$2)"}:#(typeset|export)( -[[:alnum:]]##)#( [[:alnum:]_]##)# ${(b)word}(=*| *|)})
    if (( $#line )); then
      (( $l[(Ie)$word] )) && line[1]=$'# local of zle, completion or fzf-tab — not visible in your session\n'$line[1]
      print -r -- $line[1] | bat --color=always --style=plain --language=zsh
    else
      local v=${(v)c[(I)-value-,${(b)word},*]}
      print -r -- "unset${v:+ — offered by $v}"
    fi ;;
  ('[external command]'|'[builtin command]')
    tldr --color=always -- $word 2>/dev/null || OPT_COLOR=true MANWIDTH=$FZF_PREVIEW_COLUMNS batman -- $word ;;
  (*)
    return 1
esac
