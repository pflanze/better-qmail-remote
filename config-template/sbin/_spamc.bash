

_spamc () {
    set -eu
    # adapt the socket path here:
    spamc --log-to-stderr --socket ~spamd/spamd/socket -s 10500000 "$@"
}

