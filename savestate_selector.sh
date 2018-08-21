#!/bin/bash

system="$1"
emulator="$2"
rom="$3"
command="$4"

#	set -x # START DEBUGGING
#	set +x # STOP DEBUGGING

# global variables
backtitle="Savestate Selector"
configDir=/opt/retropie/configs
declare -a menuItemsSelector

# 0 ERRORS ONLY
# 1 ERRORS and WARNING
# 2 ERRORS, WARNING and INFO
# 3 ERRORS, WARNING, INFO and DEBUG
logLevel=3
log=~/logfile.txt

# Prints messages of different severeties to a logfile
# Each message will look something like this:
# <TIMESTAMP>	<SEVERITY>	<CALLING_FUNCTION>	<MESSAGE>
# needs a set variable $logLevel
#	0 > prints ERRORS only
#	1 > prints ERRORS and WARNINGS
#	2 > prints ERRORS, WARNINGS and INFO
#	3 > prints ERRORS, WARNINGS, INFO and DEBUGGING
# needs a set variable $log pointing to a file
# Usage
# log 0 "This is an ERROR Message"
# log 1 "This is a WARNING"
# log 2 "This is just an INFO"
# log 3 "This is a DEBUG message"
function log ()
{
	severity=$1
	message=$2
	
	if [[ ${severity} -le ${logLevel} ]]
	then
		case ${severity} in
			0) level="ERROR"  ;;
			1) level="WARNING"  ;;
			2) level="INFO"  ;;
			3) level="DEBUG"  ;;
		esac
		
		printf "$(date +%FT%T%:z):\t${level}\t${FUNCNAME[1]}\t${message}\n" >> ${log} 
	fi
}

# COPIED FROM /opt/retropie/supplementary/runcommand/runcommand.sh
function start_joy2key()
{
    log 2 "()"
	
	# get the first joystick device (if not already set)
    if [[ -c "$__joy2key_dev" ]]
	then
        JOY2KEY_DEV="$__joy2key_dev"
    else
        JOY2KEY_DEV="/dev/input/jsX"
    fi
    # if joy2key.py is installed run it with cursor keys for axis, and enter + tab for buttons 0 and 1
    if [[ -f "/opt/retropie/supplementary/runcommand/joy2key.py" && -n "$JOY2KEY_DEV" ]] && ! pgrep -f joy2key.py >/dev/null
	then

        # call joy2key.py: arguments are curses capability names or hex values starting with '0x'
        # see: http://pubs.opengroup.org/onlinepubs/7908799/xcurses/terminfo.html
        "/opt/retropie/supplementary/runcommand/joy2key.py" "$JOY2KEY_DEV" kcub1 kcuf1 kcuu1 kcud1 0x0a 0x09 &
        JOY2KEY_PID=$!
    fi
}

# COPIED FROM /opt/retropie/supplementary/runcommand/runcommand.sh
function stop_joy2key() 
{
	log 2 "()"
	
    if [[ -n "$JOY2KEY_PID" ]]; then
        kill -INT "$JOY2KEY_PID"
    fi
}

function getROMFileName ()
{
	log 2 "()"
	
	rompath="${rom%/*}" # directory containing $rom
	romfilename="${rom##*/}" # filename of $rom, including extension
	romfilebase="${romfilename%%.*}" # filename of $rom, excluding extension
	romfileext="${romfilename#*.}" # extension of $rom
	
	log 3 "ROMPATH:\t${rompath}"
	log 3 "ROMFILENAME:\t${romfilename}"
	log 3 "ROMFILEBASE:\t${romfilebase}"
	log 3 "ROMFILEEXT:\t${romfileext}"
}

function getConfigValueToKey ()
{
	key="$1"
	log 2 "() \$key=${key}"
	
	log 3 "LOOKING FOR VALUE \"${key}\" IN ${configDir}/${system}/retroarch.cfg"
		
	local file=""
	
	value="$(grep --only-matching "^${key} = .*" "${configDir}/${system}/retroarch.cfg")"
	
	if [ "${value}" == "" ]
	then
		log 3 "LOOKING FOR VALUE \"${key}\" IN ${configDir}/all/retroarch.cfg"
		
		value="$(grep --only-matching "^${key} = .*" "${configDir}/all/retroarch.cfg")"
		
		if [ "${value}" == "" ]
		then
			log 1 "NO VALUE TO KEY \"${key}\" FOUND"
			return 1
		else
			file="${configDir}/all/retroarch.cfg"
		fi
	else
		file="${configDir}/${system}/retroarch.cfg"
	fi
	
	# remove key and " from result
	value=${value/$key = /}
	value=${value//\"/}
#	value=${value/\~/\/home\/pi}
	eval value="${value}"
	
	log 3 "FOUND VALUE \"${value}\" TO KEY \"${key}\" IN ${file}"
	
	return 0
}

function getSaveAndStatePath ()
{
	log 2 "()"
	
	getConfigValueToKey "savefile_directory"
	if [[ $? -eq 0 ]] && [ "${value}" != "default" ]
	then
		log 3 "FOUND VALUE \"${value}\" TO KEY \"savefile_directory\" IN CONFIGURATION FILE"
		savePath="${value}"
	else
		log 3 "FOUND NO VALUE to TO KEY \"savefile_directory\" IN CONFIGURATION FILE, USING \"${rompath}\" INSTEAD"
		savePath="${rompath}"
	fi
	
	getConfigValueToKey "savestate_directory"
	if [[ $? -eq 0 ]] && [ "${value}" != "default" ]
	then
		log 3 "FOUND VALUE \"${value}\" TO KEY \"savestate_directory\" IN CONFIGURATION FILE"
		statePath="${value}"
	else
		log 3 "FOUND NO VALUE to TO KEY \"savestate_directory\" IN CONFIGURATION FILE, USING \"${rompath}\" INSTEAD"
		statePath="${rompath}"
	fi
	
	log 2 "SAVEPATH: \"${savePath}\""
	log 2 "STATEPATH: \"${statePath}\""
}

function buildMenuItemsForSelector ()
{
	log 2 "()"

	local slot
	local item
	local lastModified
	
	# TODO add check for SRM save
	
	# add first menu items
	menuItemsSelector+=("L")
	menuItemsSelector+=("Launch ROM without Savestate") # TODO show if SRM exists
	menuItemsSelector+=("D")
	menuItemsSelector+=("Delete Savestates")
	#menuItemsSelector+=("X")
	#menuItemsSelector+=("Exit to EmulationStation")
	
	menuItemsDefault=${#menuItemsSelector[@]}
	
	log 3 "MENU ITEMS WITHOUT SAVESTATES: ${menuItemsDefault}"
	
	# add menu item for each state in $statePath
	while read stateFile
	do
		if [ "${stateFile}" == "" ]; then continue; fi
		
		log 3 "FOUND STATEFILE \"${stateFile}\""
		
		# get SLOT from extension
		slot="${stateFile#*.}" # get extension only
		slot=${slot/state/} # search "state" in $slot, replace with nothing
		if [ "${slot}" == "" ]; then slot="0"; fi # special case for slot 0 which has the extension "state"
		log 3 "IDENTIFIED AS SLOT \"${slot}\""
		
		# add stateFile to menu items
		lastModified=$(stat --format=%y "${stateFile}")
		item="Slot ${slot}, last modified ${lastModified%%.*}"
		menuItemsSelector+=("${slot}")
		menuItemsSelector+=("${item}")
		log 3 "ADDED MENU ITEM: \"${slot} ${item}"
		
		# TODO generate image per $statefile
		if [ -f "${stateFile}.png" ]
		then
			log 3 "RESIZING ${stateFile}.png..."
			
			convert \
				"${stateFile}.png" \
				-resize 320x240 \
				-background Orange label:"Slot ${slot}" +swap \
				-gravity Center \
				-append \
				"/dev/shm/state${slot}.png"
		else
			log 3 "CREATING FALLBACK THUMBNAIL..."
			
			convert \
				"/home/pi/no_thumbnail.png" \
				-background Orange label:"Slot ${slot}" +swap \
				-gravity Center \
				-append \
				"/dev/shm/state${slot}.png"
		fi
	done <<< $(find $statePath -type f -iname "${romfilebase}.state*" ! -iname "*.png" ! -iname "*.auto" | sort)
	
	log 3 "MENU ITEMS WITH SAVESTATES: ${#menuItemsSelector[@]}"
}

function showSavestateSelector ()
{
	log 2 "()"
	
	local choice
	local i
	
	log 3 "FOUND ${#menuItemsSelector[@]} MENU ITEMS"
	
	# only show dialog if items have been added, e. g. savestates have been found
	if [[ ${#menuItemsSelector[@]} -gt ${menuItemsDefault} ]]
	then
		log 3 "AT LEAST 1 SAVESTATE HAS BEEN FOUND, SHOWING DIALOG"
		
		start_joy2key
		
		refreshThumbnails
		
		choice=$(dialog \
			--backtitle "${backtitle}" \
			--title "Starting ${romfilename}..." \
			--menu "\nPlease select which SAVESTATE to start" 20 75 12 \
				"${menuItemsSelector[@]}" \
			2>&1 >/dev/tty)
		
		log 2 "SELECTED OPTION \"$choice\""
		
		pkill pngview
		
		case $choice in
			L) stop_joy2key; exit ;;
			D) showSavestateDeleter ;;
			#X) stop_joy2key; /opt/retropie/configs/all/runcommand-onend.sh && exit 1 ;;
			[0-999]) stop_joy2key; startSavestate "${choice}" ;;
			*) stop_joy2key; exit ;;
		esac
		
		# TODO show prepared images for savestates
	else
		log 3 "NO SAVESTATE HAS BEEN FOUND, SKIPPING DIALOG"
	fi
}

function showSavestateDeleter ()
{
	log 2 "()"
	
	local choice
	
	refreshThumbnails
	
	# this menu shows items 6 til end, e. g. only the statefiles
	choice=$(dialog \
		--backtitle "${backtitle}" \
		--title "Delete savestates" \
		--cancel-label "Back" \
		--menu "\nWhich savestate is to be deleted?" 25 75 20 \
			"${menuItemsSelector[@]:${menuItemsDefault}}" \
		2>&1 >/dev/tty)
			
	log 2 "SELECTED OPTION \"$choice\""
	
	pkill pngview
	
	case $choice in
		[0-999]) deleteSavestate "$choice" ;;
		*) showSavestateSelector ;;
	esac
}

function deleteSavestate ()
{
	slot="$1"
	log 2 "() \$slot=${slot}"
	
	# TODO Ask for confirmation
	
	# remove menu item from array (2 entries)
	for i in "${!menuItemsSelector[@]}"
	do
		if [ "${menuItemsSelector[i]}" == "${slot}" ]
		then
			unset -v menuItemsSelector[i]
			unset -v menuItemsSelector[++i]
			break # leave loop
		fi
	done
	
	if [ "${slot}" == "0" ]; then slot=""; fi # special case for slot 0
	
	# remove Savestate file
	log 2 "REMOVED STATEFILE \"${statePath}/${romfilebase}.state${slot}\" DISABLED"
	rm "${statePath}/${romfilebase}.state${slot}"
	if [ -f "${statePath}/${romfilebase}.state${slot}.png" ]; then rm "${statePath}/${romfilebase}.state${slot}.png"; fi

	if [ ${#menuItemsSelector[@]} -gt ${menuItemsDefault} ]
	then
		# return to showSavestateDeleter
		showSavestateDeleter
	else
		# there is no more savestate to delete or chose from
		stop_joy2key
		
		log 3 "NO MORE SAVESTATE TO DELETE OR START, EXITTING NOW"
		exit
	fi
}

function startSavestate ()
{
	slot="$1"
	log 2 "() \$slot=${slot}"
		
	log 3 "START SAVESTATE FROM SLOT ${slot}"
	
	if [[ $slot -eq 0 ]]; then slot=""; fi # special case for slot 0
	
	# copy selected slot to AUTO
	log 2 "COPIED ${statePath}/${romfilebase}.state${slot} TO ${statePath}/${romfilebase}.state.auto"
	cp -f "${statePath}/${romfilebase}.state${slot}" "${statePath}/${romfilebase}.state.auto"
	
	# remove AUTO after 10 seconds in background task (so the ROM is already started)
	(
		sleep 10
		rm "${statePath}/${romfilebase}.state.auto"
		log 2 "REMOVED ${statePath}/${romfilebase}.state.auto"
	) &
}

function refreshThumbnails ()
{
	log 2 "()"
	
	# starting position of first thumbnail
	local posx=200
	local posy=75
	
	debugPrintArray
	
	for i in ${!menuItemsSelector[@]}
	do
		# skip the default items, skip every odd item
		if [[ $i -lt ${menuItemsDefault} ]] || [[ $(( i % 2 )) -eq 1 ]]; then continue; fi
		
		# skip every other item
		#if [[ $(( i % 2 )) -eq 1 ]]; then continue; fi
		
		log 3 "SHOWING THUMBNAIL FOR SLOT ${menuItemsSelector[i]}"
		
		nohup pngview -b 0 -l 10000 /dev/shm/state${menuItemsSelector[i]}.png -x ${posx} -y ${posy} &>/dev/null &
		
		# TODO compute better coordinates for thumbnails
		(( posy=posy + 325 ))
	done
}

function debugPrintArray ()
{
	for i in ${!menuItemsSelector[@]}
	do
		log 3 "INDEX = ${i}, CONTENT = ${menuItemsSelector[i]}"
	done
}

log 2 "()"

log 3 "\$1 SYSTEM:\t${system}"
log 3 "\$2 EMULATOR:\t${emulator}"
log 3 "\$3 ROM:\t${rom}"
log 3 "\$4 COMMAND:\t${command}"

getROMFileName
getSaveAndStatePath
buildMenuItemsForSelector
showSavestateSelector

log 2 "EXIT"