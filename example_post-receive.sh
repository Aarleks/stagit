#!/bin/sh
# generic git post-receive hook.
# change the config options below and call this script in your post-receive
# hook or symlink it.
#
# NOTE, things to do manually (once) before running this script:
# - modify the categories in the for loop with your own.
#
# usage: $0 [name]
#
# if name is not set the basename of the current directory is used,
# this is the directory of the repo when called from the post-receive script.

# NOTE: needs to be set for correct locale (expects UTF-8) otherwise the
#       default is LC_CTYPE="POSIX".
export LC_CTYPE="en_US.UTF-8"

name="$1"
if test "${name}" = ""; then
    name="$(basename "$(pwd)")"
fi

# paths must be absolute
reposdir="/var/www/git"
dir="${reposdir}/${name}"
destdir="/var/www/stagit"
cachefile=".stagit-build-cache"

if ! test -d "${dir}"; then
    echo "${dir} does not exist" >&2
    exit 1
fi
cd "${dir}" || exit 1

[ -f "${dir}/git-daemon-export-ok" ] || exit 0

# detect git push -f
force=0
while read -r old new ref; do
    test "${old}" = "0000000000000000000000000000000000000000" && continue
    test "${new}" = "0000000000000000000000000000000000000000" && continue

    hasrevs="$(git rev-list "${old}" "^${new}" | sed 1q)"
    if test -n "${hasrevs}"; then
        force="1"
        break
    fi
done

# strip .git suffix
r="$(basename "${name}")"
d="$(basename "${name}" ".git")"
printf "[%s] stagit HTML pages... " "${d}"

# remove folder if forced update
[ "${force}" = "1" ] && printf "forced update... " && rm -rf "${destdir}/${d}"

mkdir -p "${destdir}/${d}"
cd "${destdir}/${d}" || exit 1

# make pages
stagit -c "${cachefile}" -u "git://git.alexnorman.xyz/$d/" "${reposdir}/${r}"
[ -f "about.html" ] \
    && ln -sf "about.html" "index.html" \
    || ln -sf "log.html" "index.html"
ln -sfT "${dir}" ".git"

# generate index arguments
args=""
for cat in "Projects" "Forks"; do
    args="$args -c \"$cat\""
    for dir in "$reposdir/"*.git/; do
        dir="${dir%/}"
        [ ! -f "$dir/git-daemon-export-ok" ] && continue
        if [ -f "$dir/category" ]; then
            [ "$(cat "$dir/category")" = "$cat" ] && args="$args $dir"
        else
            stagit_uncat="1"
        fi
    done
done

if [ -n "$stagit_uncat" ]; then
    args="$args -c Uncategorized"
    for dir in "$reposdir/"*.git/; do
        dir="${dir%/}"
        [ -f "$dir/git-daemon-export-ok" ] && [ ! -f "$dir/category" ] && \
            args="$args $dir"
    done
fi

# make index
echo "$args" | xargs stagit-index > "${destdir}/index.html"

echo "done"
