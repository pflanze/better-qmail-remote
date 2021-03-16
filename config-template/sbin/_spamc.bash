
socketdir=/var/qmail/spamd-socket-for-qmailr

_spamc () {
    set -eu
    spamc --log-to-stderr --socket "$socketdir"/socket -s 10500000 "$@"
}

