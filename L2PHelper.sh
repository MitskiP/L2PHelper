#!/bin/bash
# This script downloads missing homeworks or learning materials from the RWTH-L2P automatically.
# The parameter -f forces the script to download all the files from the server again.
# While this script is running the owncloud client is paused (if it is running).

url='https://www3.elearning.rwth-aachen.de/l2p/foyer/SitePages/MyCourses.aspx'

cd "`dirname "$0"`" || exit 2

# load config file
cfg="`basename "$0"`"
cfg="${cfg%.*}.cfg"

[ -f "$cfg" ] && . "./$cfg"

if ! [ "$user" -a "$pw" ]; then
	if [ ! -f "$cfg" ]; then
		cat << '		EOF' | sed 's/\t//g' > "$cfg"
			#!/bin/bash
			# Config file for elearning.sh

			parse[0]='Formale Systeme, Automaten, Prozesse//Learning Materials/*'
			parse[1]='Einführung in die angewandte Stochastik//Learning Materials/*'
			parse[2]='Betriebssysteme und Systemsoftware//Learning Materials/*'
			parse[3]='Betriebssysteme und Systemsoftware//Shared Documents/Aufgaben für die Übungsgruppen/*'
			parse[4]='Betriebssysteme und Systemsoftware//Assignments/*'

			user= #user name here
			pw= #password here
		EOF
	fi
	echo "Please configure $cfg and set your user name and password."
	exit 1
fi

# check for available commands and create if necessary
progdir="$(pwd)"
fgcolor() {
	case "$1" in
		0 | [bB]lack) echo -en "\E[0;30m" ;;
		1 | [rR]ed) echo -en "\E[0;31m" ;;
		2 | [gG]reen) echo -en "\E[0;32m" ;;
		3 | [yY]ellow) echo -en "\E[0;33m" ;;
		4 | [bB]lue) echo -en "\E[0;34m" ;;
		5 | [pP]urple) echo -en "\E[0;35m" ;;
		6 | [cC]yan) echo -en "\E[0;36m" ;;
		7 | [wW]hite) echo -en "\E[0;37m" ;;
		8 | [bB]old) echo -en "\033[0;1m" ;;
		9 | [uU]nderline) echo -en "\033[0;4m" ;;
		-1 | [sS]top) tput sgr0 ;;
		*) echo -en "$1";;
	esac
	shift
	[ $# -gt 0 ] && fgcolor "$@"
}
if testmktemp="`mktemp 2>/dev/null`" && [ -f "$testmktemp" ]; then
	rm "$testmktemp"
else
	mktemp() {
		local t="$progdir/$$"
		while [ -f "$t" ]; do
			t="$t$$"
		done
		touch "$t"
		echo "$t"
	}
fi
if ! which uconv &>/dev/null; then
	# this command is not that important; e.g. Ü can be represented in multiple ways
	# which may result in having directories which have the "same name"
	uconv() {
		cat
	}
fi
if ! which wget &>/dev/null; then
	echo "Please install wget."
	exit 3
fi
#############

quit() {
	[ -f "$mainfile" ] && rm "$mainfile"
	[ -f "$modfile" ] && rm "$modfile"
	[ -f "$dirfile" ] && rm "$dirfile"
	[ "$1" ] && echo "$1"
	exit $2
}
trap "quit Aborted. 9" SIGINT SIGTERM

mainfile="`mktemp`"
modfile="`mktemp`"
dirfile="`mktemp`"

[ "$1" == -f ] && shift && force=y || force=n

dload() { # downloader
	wget -qN --header='Accept-Language: en-us' --http-user="$user" --http-password="$pw" "$@"
}
dmain() { # main page downlaoder
	#return
	dload "$url" -O "$mainfile"
}
dmodule() { # module downloader
	#return
	dload "$modlink" -O "$modfile"
}
ddir() { # subpage (of subpages or module pages) downloader
	dload "$dirlink" -O "$dirfile"
}
dfile() { # file downloader
	local link="$1"
	local name="$2"
	[ -f "$2" ] || fgcolor red "Downloading new file: $2...\n" stop
	[ "$force" == y ] && local name="$name.new.$$"
	# sometimes pdf files are not correctly downloaded somehow; this is a workaround
	dload -c "$link" -O "$name"
	if [[ "$2" =~ \.pdf$ ]]; then
		while ! pdfinfo "$name" &>/dev/null; do
			fgcolor red "another try\n" stop
			rm "$name"
			wget -N --header='Accept-Language: en-us' --http-user="$user" --http-password="$pw" -c "$link" -O "$name"
			#dload -c "$link" -O "$name"
		done
	fi
	if [ "$force" == y ]; then
		[ -f "$2" ] && { cmp "$name" "$2" &>/dev/null && rm "$name" && return || fgcolor red "Updated File: $2\n" stop; }
		mv "$name" "$2"
	fi
}
dmain

baseurl="`sed 's#\(http[s]\{1\}://[^/]*\)/.*#\1#' <<< "$url"`"

# this is the most important function as it has to fetch all the urls from the html files
grabber() {
	grep 'onmousedown="[^"]*Verify\(Folder\)\{0,1\}Href' "$dirfile" | sed -e 's/href="/\n/g' | grep '^/' | sed -e 's#".*title="Folder: \([^"]*\)".*#///\1#' -e 's/".*//' | grep -v 'aspx\(?ID=[0-9]*\)\{0,1\}$' | uniq
	grep -B99999 '<hr' "$dirfile" | grep -A99999 'Assignments List for holding' | grep 'href="http' | sed -e 's/href="http/\nhref="http/g' | sed -e 's#.*href="\(http[^"]*\)".*>\([^<>]*\)</a>.*#\1///\2#' -e 's/\&amp;/\&/g' | grep "^http"
	sed -n 's/.*LinkTitle" href="\([^"]*\)".*/\1/p' "$dirfile"
}
# work recursively through the download path
dloadDir() {
	local nextdir="${1%%/*}"
	local rest="${1#*/}"
	while IFS='' read -r node; do
		if grep 'RootFolder=\|ListId=' <<< "$node" &>/dev/null; then
			local fname="`uconv -x Any-NFC <<< "${node#*///}"`"
			[ "$fname" != "$node" ] || continue
			#echo "fname|$fname   nextdir|$nextdir"
			[ "$nextdir" != '*' -a "$nextdir" != "$fname" ] && continue
			node="${node%///*}"
			echo "Folder: $node @ $fname"
			dirlink="$node"
			grep "^$baseurl" <<< "$dirlink" &>/dev/null || dirlink="$baseurl$dirlink"
			ddir
			[ -d "$fname" ] || fgcolor red "Creating $fname...\n" stop
			mkdir -p "$fname"
			cd "$fname"
			dloadDir "$rest"
			cd ..
		elif [ "$nextdir" == '*' ]; then
			fname="`uconv -x Any-NFC <<< "$(basename "$node")"`"
			echo "File: $node"
			dfile "$baseurl$node" "$fname"
		fi
	done < <(grabber)
}

# pause owncloud
poc="`pgrep 'owncloud'`"
[ "$force" == y -a "$poc" ] && kill -STOP "$poc"
# main
for p in "${parse[@]}"; do
	# get module page
	module="${p%%//*}"
	module="${module//\//.}"
	p="${p#*//}"
	modlink="$baseurl`grep "$module" "$mainfile" | grep href | sed -e "s#.*href=$baseurl\([^>]*\)>$module.*#\1#"`"
	echo
	fgcolor blue "$module" stop ": $modlink\n"
	dmodule
	# get sub page (i.e. menu entry, left pane)
	menu="${p%%/*}"
	p="${p#*/}"
	dirlink="`grep "$menu" "$modfile" | grep aspx | head -1 | sed -e "s#.*href='##" -e "s#aspx.*#aspx#"`"
	echo "$menu: $dirlink"
	# start the recursive work
	ddir
	mkdir -p "$module"
	cd "$module"
	dloadDir "$p"
	cd ..
done
# continue owncloud
[ "$force" == y -a "$poc" ] && kill -CONT "$poc"

# clean up
quit "Done." 0

