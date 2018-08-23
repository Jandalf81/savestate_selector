#!/bin/bash

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


# load INI variables
source ./savestate_selector.cfg

# global variables
backtitle="Savestate Selector (https://github.com/Jandalf81/savestate_selector)"


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

function setConfigValue ()
{
	key="$1"
	value="$2"
	
	log 3 "() \$key=${key} \$value=${value}"
	
	log 2 "UPDATING KEY ${key} TO VALUE ${value} IN savestate_selector.cfg"
	sed -i "/^${key}=/c\\${key}=\"${value}\"" ./savestate_selector.cfg
}

function mainMenu ()
{
	log 3 "()"
	
	local choice="0"
	
	while true
	do
		getStatusOfParameters
		
		choice=$(dialog \
			--colors \
			--backtitle "${backtitle}" \
			--title "Main Menu" \
			--default-item "${choice}" \
			--cancel-label "Exit" \
			--menu "\nWhat do you want to do?" 25 75 20 \
				0 "Enable SAVESTATE_SELECTOR (currently ${statusEnabled})" \
				1 "Show thumbnails (currently ${statusShowThumbnails})" \
				2 "Set delay to delete AUTO savestate (currently ${deleteDelay} seconds)" \
				3 "Set sort order for savestates (currently \"${statusSortOrder}\")" \
				4 "Set log level (currently \"${statusLogLevel}\")" \
			2>&1 >/dev/tty)
			
		log 3 "SELECTED OPTION ${choice}"
			
		case ${choice} in
			0) toggleEnabled ;;
			1) toggleShowThumbnails ;;
			2) setDeleteDelay ;;
			3) setSortOrder ;;
			4) setLogLevel ;;
			*) break ;;
		esac
	done
}

function getStatusOfParameters ()
{
	log 3 "()"
	
	if [ "${enabled}" == "TRUE" ]
	then
		statusEnabled="${GREEN}ENABLED${NORMAL}"
	else
		statusEnabled="${RED}DISABLED${NORMAL}"
	fi
	
	if [ "${showThumbnails}" == "TRUE" ]
	then
		statusShowThumbnails="${GREEN}ENABLED${NORMAL}"
	else
		statusShowThumbnails="${RED}DISABLED${NORMAL}"
	fi
	
	case ${sortOrder} in
		0) statusSortOrder="last modified DESC" ;;
		1) statusSortOrder="last modified" ;;
		2) statusSortOrder="slot number DESC" ;;
		3) statusSortOrder="slot number" ;;
		*) statusSortOrder="unknown" ;;
	esac
	
	case ${logLevel} in
		-1) statusLogLevel="No logging" ;;
		0) statusLogLevel="ERROR only" ;;
		1) statusLogLevel="ERROR and WARNING" ;;
		2) statusLogLevel="ERROR, WARNING and INFO" ;;
		3) statusLogLevel="ERROR, WARNING, INFO and DEBUG" ;;
		*) statusLogLevel="unknown" ;;
	esac
}

function toggleEnabled ()
{
	log 3 "()"
	
	if [ "${enabled}" == "TRUE" ]
	then
		enabled="FALSE"
	else
		enabled="TRUE"
	fi
	
	setConfigValue "enabled" "${enabled}"
}

function toggleShowThumbnails ()
{
	log 3 "()"
	
	if [ "${showThumbnails}" == "TRUE" ]
	then
		showThumbnails="FALSE"
	else
		showThumbnails="TRUE"
	fi
	
	setConfigValue "showThumbnails" "${showThumbnails}"
}

function setDeleteDelay ()
{
	log 3 "()"
	
	choice=$(dialog \
		--colors \
		--backtitle "${backtitle}" \
		--title "Set delete delay" \
		--default-item "${deleteDelay}" \
		--cancel-label "Back" \
		--menu "\nPlease select the time after which the AUTO savestate will be deleted" 25 75 20 \
			5 "5 seconds" \
			10 "10 seconds" \
			15 "15 seconds" \
			20 "20 seconds" \
			25 "25 seconds" \
			30 "30 seconds" \
			35 "35 seconds" \
			40 "40 seconds" \
			45 "45 seconds" \
			50 "50 seconds" \
			55 "55 seconds" \
			60 "60 seconds" \
		2>&1 >/dev/tty)
	
	if [ "${choice}" == "" ]; then return
	elif (( ${choice} >= 5 && ${choice} <= 60 ))
	then
		deleteDelay=${choice}
		
		setConfigValue "deleteDelay" "${deleteDelay}"
	fi		
}

function setSortOrder ()
{
	log 3 "()"
	
	choice=$(dialog \
		--colors \
		--backtitle "${backtitle}" \
		--title "Set sort order" \
		--default-item "${sortOrder}" \
		--cancel-label "Back" \
		--menu "\nPlease select the sort order for the list of savestates" 25 75 20 \
			0 "Sort by \"last modified DESC\"" \
			1 "Sort by \"last modified\"" \
			2 "Sort by \"slot number DESC\"" \
			3 "Sort by \"slot number\"" \
		2>&1 >/dev/tty)
	
	if [ "${choice}" == "" ]; then return
	elif (( ${choice} >= 0 && ${choice} <= 3 ))
	then
		sortOrder=${choice}
		
		setConfigValue "sortOrder" "${sortOrder}"
	fi		
}

function setLogLevel ()
{
	log 3 "()"
	
	choice=$(dialog \
		--colors \
		--backtitle "${backtitle}" \
		--title "Set sort order" \
		--default-item "${logLevel}" \
		--cancel-label "Back" \
		--menu "\nPlease select the log level" 25 75 20 \
			-1 "No logging at all" \
			0 "ERROR only" \
			1 "ERROR and WARNING" \
			2 "ERROR, WARNING and INFO" \
			3 "ERROR, WARNING, INFO and DEBUG" \
		2>&1 >/dev/tty)
	
	if [ "${choice}" == "" ]; then return
	elif (( ${choice} >= -1 && ${choice} <= 3 ))
	then
		logLevel=${choice}
		
		setConfigValue "logLevel" "${logLevel}"
	fi		
}

mainMenu