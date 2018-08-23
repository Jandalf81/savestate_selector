#!/bin/bash

# define colors for output
NORMAL="\Zn"
BLACK="\Z0"
RED="\Z1"
GREEN="\Z2"
YELLOW="\Z3\Zb"
BLUE="\Z4"
MAGENTA="\Z5"
CYAN="\Z6"
WHITE="\Z7"
BOLD="\Zb"
REVERSE="\Zr"
UNDERLINE="\Zu"

# parameters
system="$1"
emulator="$2"
rom="$3"
command="$4"

# load INI variables
source ~/scripts/savestate_selector/savestate_selector.cfg

# global variables
backtitle="Savestate Selector (https://github.com/Jandalf81/savestate_selector)"
configDir=/opt/retropie/configs
declare -a menuItems


# Prints messages of different severeties to a logfile
# Each message will look something like this:
# <TIMESTAMP>	<SEVERITY>	<CALLING_FUNCTION>	<MESSAGE>
# needs a set variable $logLevel
#	-1 > No logging at all
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
	
	if (( ${severity} <= ${logLevel} ))
	then
		case ${severity} in
			0) level="ERROR"  ;;
			1) level="WARNING"  ;;
			2) level="INFO"  ;;
			3) level="DEBUG"  ;;
		esac
		
		printf "$(date +%FT%T%:z):\t${level}\t${0##*/}\t${FUNCNAME[1]}\t${message}\n" >> ${log} 
	fi
}

# COPIED FROM /opt/retropie/supplementary/runcommand/runcommand.sh
function start_joy2key()
{
    log 3 "()"
	
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
	log 3 "()"
	
    if [[ -n "$JOY2KEY_PID" ]]; then
        kill -INT "$JOY2KEY_PID"
    fi
}

function getROMFileName ()
{
	log 3 "()"
	
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
	log 3 "() \$key=${key}"
	
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
	eval value="${value}"
	
	log 3 "FOUND VALUE \"${value}\" TO KEY \"${key}\" IN ${file}"
	
	return 0
}

function setConfigValue ()
{
	key="$1"
	value="$2"
	
	log 3 "() \$key=${key} \$value=${value}"
	
	if [[ $(grep -c --only-matching "^${key} = .*" "${configDir}/${system}/retroarch.cfg") -eq 1 ]]
	then
		log 3 "UPDATING KEY ${key} TO VALUE ${value} IN ${configDir}/${system}/retroarch.cfg"
		sudo sed -i "/^${key} = /c\\${key} = \"${value}\"" ${configDir}/${system}/retroarch.cfg
	else
		if [[ $(grep -c --only-matching "^${key} = .*" "${configDir}/all/retroarch.cfg") -eq 1 ]]
		then
			log 3 "UPDATING KEY ${key} TO VALUE ${value} IN ${configDir}/all/retroarch.cfg"
			sudo sed -i "/^${key} = /c\\${key} = \"${value}\"" ${configDir}/all/retroarch.cfg
		else
			log 3 "ADDING KEY ${key} TO ${configDir}/${system}/retroarch.cfg"
			# add new parameter above "#include..."
			sudo sed -i "/^#include \"\/opt\/retropie\/configs\/all\/retroarch.cfg\"/c\\${key} = /c\\${key} = \"${value}\"\n#include \"\/opt\/retropie\/configs\/all\/retroarch.cfg\"" ${configDir}/${system}/retroarch.cfg
		fi
	fi
	
}

function getSaveAndStatePath ()
{
	log 3 "()"
	
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

function buildMenuItems ()
{
	log 3 "()"
	
	declare -a stateFiles
	
	# build list of SAVESTATEs
	while read stateFile
	do
		# skip empty lines
		if [ "${stateFile}" == "" ]; then continue; fi
		
		# prepare item
		slot="${stateFile##*.}"
		slot=${slot/state/}
		if [ "${slot}" == "" ]; then slot="0"; fi
		file="${stateFile##*/}"
		lastModified=$(stat --format=%y "${stateFile}")
		lastModified="${lastModified%%.*}"
		text="Slot ${slot}, last modified ${lastModified}"
		
		# add item to list
		stateFiles+=("${slot}|${file}|${lastModified}|${text}")
	done <<< $(find $statePath -type f -iname "${romfilebase}.state*" ! -iname "*.png" ! -iname "*.auto") # get all STATE files, exclude *.PNG and *.AUTO
	
	log 2 "FOUND ${#stateFiles[@]} SAVESTATES"
	
	# define sortString
	case ${sortOrder} in
		0) sortString="rk 3,3" ;; # LASTMODIFIED (text) DESC
		1) sortString="k 3,3" ;; # LASTMODIFIED (text)
		2) sortString="nrk 1,1" ;; # SLOT (numeric) DESC
		3) sortString="nk 1,1" ;; # SLOT (numeric)
		*) sortString="rk 3,3" ;; # LASTMODIFIED (text) DESC
	esac
	
	# check for SRM save
	if [ -f "${savePath}/${romfilebase}.srm" ]
	then
		srmStatus="${GREEN}"
	else
		srmStatus="${RED}No "
	fi
	
	# add default items to list of menu items
	menuItems+=("L" "Launch ROM without Savestate (${srmStatus}Battery Save found${NORMAL})")
	menuItems+=("D" "Delete Savestates")
	
	menuItemsDefault=${#menuItems[@]}
	
	# add menu items for each SAVESTATE to list of menu items
	while read stateFile
	do
		# skip empty lines
		if [ "${stateFile}" == "" ]; then continue; fi
		
		# split each line
		IFS="|"
		read -ra line <<< ${stateFile}
		
		menuItems+=("${line[0]}" "${line[3]}") # SLOT ITEM
	done <<< $(printf "%s\n" "${stateFiles[@]}" | sort -${sortString} -t"|")
}

function showSavestateSelector ()
{
	log 3 "()"
	
	local choice
	local i
	
	log 3 "FOUND ${#menuItems[@]} MENU ITEMS"
	
	# only show dialog if items have been added, e. g. savestates have been found
	if [[ ${#menuItems[@]} -gt ${menuItemsDefault} ]]
	then
		log 3 "AT LEAST 1 SAVESTATE HAS BEEN FOUND, SHOWING DIALOG"
		
		start_joy2key # needed to control the dialog with a gamepad
		
		if [ "${showThumbnails}" == "TRUE" ]; then refreshThumbnailMontage; fi
		
		log 3 "WAITING FOR USER INPUT"
		
		choice=$(dialog \
			--colors \
			--backtitle "${backtitle}" \
			--title "Starting ${romfilename}..." \
			--no-cancel \
			--menu "\nPlease select which SAVESTATE to start" 20 75 12 \
				"${menuItems[@]}" \
			2>&1 >/dev/tty)
		
		log 2 "SELECTED OPTION \"$choice\""
		
		# react to choice
		if [ "${choice}" == "" ]; then startROM
		elif [ "${choice}" == "L" ]; then startROM
		elif [ "${choice}" == "D" ]; then showSavestateDeleter
		elif (( ${choice} >= 0 && ${choice} <= 999 )); then startSavestate "${choice}"
		else startROM
		fi
	else
		log 2 "NO SAVESTATE HAS BEEN FOUND, SKIPPING DIALOG"
	fi
}

function startROM ()
{
	log 3 "()"
	
	log 3 "SETTING DEFAULT CONFIG PARAMETERS"
	setConfigValue "state_slot" "0"
	setConfigValue "savestate_auto_load" "false"
	if [ "${showThumbnails}" == "TRUE" ]; then setConfigValue "savestate_thumbnail_enable" "true"; fi # create THUMBNAILS on SAVESTATE creation
	
	pkill pngview
	
	stop_joy2key
}

function showSavestateDeleter ()
{
	log 3 "()"
	
	local choice
	
	log 3 "SHOW MENU DIALOG"
	
	if [ "${showThumbnails}" == "TRUE" ]; then refreshThumbnailMontage; fi
	
	log 3 "WAITING FOR USER INPUT"
	
	# this menu shows anything but the default items, e. g. only the statefiles
	choice=$(dialog \
		--colors \
		--backtitle "${backtitle}" \
		--title "Delete savestates" \
		--cancel-label "Back" \
		--menu "\nWhich savestate is to be ${RED}deleted${NORMAL}?" 20 75 12 \
			"${menuItems[@]:${menuItemsDefault}}" \
		2>&1 >/dev/tty)
			
	log 2 "SELECTED OPTION \"$choice\""
	
	if [ "${choice}" == "" ]; then showSavestateSelector
	elif (( ${choice} >= 0 && ${choice} <= 999 )); then deleteSavestate "$choice" 
	fi
}

function deleteSavestate ()
{
	slot="$1"
	log 3 "() \$slot=${slot}"
	
	# show DELETE MARKER overlay
	if [ "${showThumbnails}" == "TRUE" ]; then showDeleteOverlay "${choice}"; fi
	
	# ask for confirmation
	local choice
	
	log 3 "AWAITING CONFIRMATION"
	dialog \
		--colors \
		--backtitle "${backtitle}" \
		--title "Confirm deletion" \
		--yesno "\nDo you really want to ${RED}delete${NORMAL}\n\n${YELLOW}${statePath}/${romfilebase}.state${slot}${NORMAL}\n\nThis can ${RED}not be undone${NORMAL}!" 20 75 \
		2>&1 >/dev/tty
	
	choice=$?
	
	# remove DELETE MARKER overlay
	if [ "${pidDeleteOverlay}" != "" ]; then kill -INT ${pidDeleteOverlay}; fi
	
	log 3 "SELECTED OPTION ${choice}"
	
	if [[ ${choice} -eq 0 ]]
	then
		# remove menu item from array (2 entries)
		for i in "${!menuItems[@]}"
		do
			if [ "${menuItems[i]}" == "${slot}" ]
			then
				unset -v menuItems[i]
				unset -v menuItems[++i]
				break # leave loop
			fi
		done
		
		if [ "${slot}" == "0" ]; then slot=""; fi # special case for slot 0
		
		# remove Savestate file
		log 2 "REMOVED STATEFILE \"${statePath}/${romfilebase}.state${slot}\""
		rm "${statePath}/${romfilebase}.state${slot}"
		if [ -f "${statePath}/${romfilebase}.state${slot}.png" ]; then rm "${statePath}/${romfilebase}.state${slot}.png"; fi

		if [ ${#menuItems[@]} -gt ${menuItemsDefault} ]
		then
			# return to showSavestateDeleter
			showSavestateDeleter
		else
			# there is no more savestate to delete or chose from
			log 2 "NO MORE SAVESTATE TO DELETE OR START, STARTING ROM NOW"
			startROM
		fi
	else
		# return to dialog
		showSavestateDeleter
	fi
}

function showDeleteOverlay ()
{
	slot="$1"
	log 3 "() \$slot=${slot}"
	
	local position
	local offset
	local posx
	local posy
	local j=0

	# get index of $menuItem to $slot
	for i in ${!menuItems[@]}
	do
		if [ "${slot}" == "${menuItems[$i]}" ]
		then
			offset=$(( $i - $j )) # compute the offset: index of item minus real position (deleting items creates gaps, this compensates these gaps)
			position=$(( ((${i} - 4 - ${offset}) / 2) + 1 )) # compute the position of the thumbnail to delete
			
			log 3 "FOUND SLOT ${slot} AT POSTION ${position}"
			break
		fi
		
		let j++
	done
	
	# set coords according to $position
	case ${position} in
		1) posx=75; posy=40 ;;
		2) posx=555; posy=40 ;;
		3) posx=1035; posy=40 ;;
		4) posx=1515; posy=40 ;;
		5) posx=75; posy=390 ;;
		6) posx=1515; posy=390 ;;
		7) posx=75; posy=740 ;;
		8) posx=555; posy=740 ;;
		9) posx=1035; posy=740 ;;
		10) posx=1515; posy=740 ;;
		*) posx=0; posy=0 ;;
	esac
	
	if [[ ${posx} -ne 0 ]]
	then
		log 3 "SHOWING DELETE MARKER AT ${posx}, ${posy}"
		nohup pngview -b 0 -l 10001 "/home/pi/delete.png" -x ${posx} -y ${posy} &> /dev/null &
		
		# save pid to kill the process later
		pidDeleteOverlay=$!
	fi
}

function startSavestate ()
{
	slot="$1"
	log 3 "() \$slot=${slot}"
		
	log 2 "START SAVESTATE FROM SLOT ${slot}"
	
	# set parameters in CFG
	setConfigValue "savestate_auto_load" "true" # load SAVESTATE named AUTO
	setConfigValue "state_slot" "${slot}" # set SLOT to slot of selected SAVESTATE
	if [ "${showThumbnails}" == "TRUE" ]; then setConfigValue "savestate_thumbnail_enable" "true"; fi # create THUMBNAILS
	
	if [[ $slot -eq 0 ]]; then slot=""; fi # special case for slot 0
	
	# copy selected slot to AUTO
	log 2 "COPIED ${statePath}/${romfilebase}.state${slot} TO ${statePath}/${romfilebase}.state.auto"
	cp -f "${statePath}/${romfilebase}.state${slot}" "${statePath}/${romfilebase}.state.auto"
	
	# copy tumbnail to LAUNCHING image
	#cp -f "${statePath}/${romfilebase}.state${slot}.png" "${rompath}/images/${romfilebase}-launching.png"
	
	log 2 "WILL REMOVE ${statePath}/${romfilebase}.state.auto IN ${deleteDelay} SECONDS..."
	
	pkill pngview
	
	stop_joy2key
	
	# remove AUTO after 10 seconds in background task (so the ROM is already started)
	(
		sleep ${deleteDelay}
		rm "${statePath}/${romfilebase}.state.auto"
		#rm "${rompath}/images/${romfilebase}-launching.png"
		log 2 "REMOVED ${statePath}/${romfilebase}.state.auto"
	) &
}

function refreshThumbnailMontage ()
{
	log 3 "()"
	
	# only create a new montage if the number of menu items has been changed since the last run
	if [[ ${oldNumberOfMenuItems} -ne ${#menuItems[@]} ]]
	then
		log 2 "PREPARING NEW THUMBNAIL MONTAGE"
		
		pkill pngview
		
		# msgbox CREATING PREVIEW
		dialog \
			--colors \
			--backtitle "${backtitle}" \
			--title "Generating Previews..." \
			--infobox "\nThis may take some seconds...\n\n(The Previews can\nbe ${YELLOW}disabled${NORMAL} in the configuration)" 10 40 \
			2>&1 >/dev/tty
			
		declare -a thumbnailFile
		
		# initialize array
		for i in 0 1 2 3 4 5 6 7 8 9 # $(seq 0 9)
		do
			thumbnailFile[i]=null:
		done
		
		local tnF=0
		
		# save current number of menu items for future runs
		oldNumberOfMenuItems=${#menuItems[@]}
		
		# fill array with references to thumbnails
		for mi in ${!menuItems[@]}
		do	
			# skip the default items, skip every odd item
			if [[ $mi -lt ${menuItemsDefault} ]] || [[ $(( mi % 2 )) -eq 1 ]]; then continue; fi
			
			# stop this after 10 thumbnails
			if [[ $tnF -ge 10 ]]; then break; fi
			
			# get SLOT from menuItem
			slot=${menuItems[mi]}
			log 3 "GOT SLOT ${slot} FROM \$menuItems"
			if [[ ${slot} -eq 0 ]]; then slot=""; fi # special case for slot 0
			
			log 3 "CHECKING FILE ${statePath}/${romfilebase}.state${slot}.png"
			
			# check if there's a thumbnail for the currenct thumbnailFile
			if [ -f "${statePath}/${romfilebase}.state${slot}.png" ]
			then
				log 3 "FOUND THUMBNAIL ${statePath}/${romfilebase}.state${slot}.png"
				thumbnailFile[tnF]="${statePath}/${romfilebase}.state${slot}.png"
				let tnF++
			else
				log 3 "NO THUMBNAIL FOUND, USING FALLBACK"
				cp "/home/pi/no_thumbnail.png" "/dev/shm/${romfilebase}.state${slot}.png"
				thumbnailFile[tnF]="/dev/shm/${romfilebase}.state${slot}.png"
				let tnF++
			fi
		done
		
		# create montage based on &thumbnailFile
		log 2 "CREATING NEW THUMBNAIL MONTAGE"
		montage \
			-label '%[basename]' \
			"${thumbnailFile[0]}" \
			"${thumbnailFile[1]}" \
			"${thumbnailFile[2]}" \
			"${thumbnailFile[3]}" \
			"${thumbnailFile[4]}" \
			"null:" \
			"null:" \
			"${thumbnailFile[5]}" \
			"${thumbnailFile[6]}" \
			"${thumbnailFile[7]}" \
			"${thumbnailFile[8]}" \
			"${thumbnailFile[9]}" \
			-tile 4x3 \
			-geometry 320x240+75+40 \
			-background transparent \
			-shadow \
			-frame 5 \
			"/dev/shm/savestate_selector.png" >> ${log}
		
		log 2 "SHOWING THUMBNAIL MONTAGE"
		nohup pngview -b 0 -l 10000 "/dev/shm/savestate_selector.png" -x 0 -y 0 &>/dev/null &
	else
		log 2 "NO CHANGE, RE-USING THUMBNAIL MONTAGE"
	fi	
}

function debugPrintArray ()
{
	for i in ${!menuItems[@]}
	do
		log 3 "INDEX = ${i}, CONTENT = ${menuItems[i]}"
	done
}

log 3 "()"

log 3 "\$1 SYSTEM:\t${system}"
log 3 "\$2 EMULATOR:\t${emulator}"
log 3 "\$3 ROM:\t${rom}"
log 3 "\$4 COMMAND:\t${command}"

if [ "${enabled}" != "TRUE" ]
then
	log 2 "SAVESTATE_SELECTOR IS CURRENTLY DISABLED"
	exit
fi

getROMFileName
getSaveAndStatePath
buildMenuItems
showSavestateSelector

pkill pngview
stop_joy2key