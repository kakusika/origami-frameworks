default:
    @just --list

update-ayame:
    nix flake udpate ayame
    cargo update ayame

update-cxx-qt:
    git fetch upstream
    git checkout fix/qmlls-ini-readonly-source
    git rebase upstream/mai
    git push --force-with-lease
