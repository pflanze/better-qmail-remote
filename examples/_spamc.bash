

_spamc () {
    set -eu
    # adapt the socket path here:
    spamc --socket ~spamd/spamd/socket -s 10500000 "$@"
}

