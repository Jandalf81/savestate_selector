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


backtitle="SAVESTATE_SELECTOR uninstaller (https://github.com/Jandalf81/savestate_selector)"

logLevel=3
log=~/scripts/savestate_selector/savestate_selector-uninstall.log

declare -a steps


##################
# WELCOME DIALOG #
##################
dialog \
	--stdout \
	--backtitle "${backtitle}" \
	--title "Welcome" \
	--colors \
	--no-collapse \
	--cr-wrap \
	--yesno \
		"\nThis script will ${RED}uninstall SAVESTATE_SELECTOR${NORMAL}.\n\nAre you sure you wish to continue?" \
	20 90 2>&1 > /dev/tty \
    || exit

	
####################
# HELPER FUNCTIONS #
####################
	
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


####################
# DIALOG FUNCTIONS #
####################


# Build progress from array $STEPS()
# INPUT
#	$steps()
# OUTPUT
#	$progress
function buildProgress ()
{
	progress=""
	
	for ((i=0; i<=${#steps[*]}; i++))
	do
		progress="${progress}${steps[i]}\n"
	done
}

# Show Progress dialog
# INPUT
#	1 > Percentage to show in dialog
#	$backtitle
#	$progress
function dialogShowProgress ()
{
	local percent="$1"
	
	buildProgress
	
	clear
	clear
	
	echo "${percent}" | dialog \
		--stdout \
		--colors \
		--no-collapse \
		--cr-wrap \
		--backtitle "${backtitle}" \
		--title "Uninstaller" \
		--gauge "${progress}" 36 90 0 \
		2>&1 > /dev/tty
		
	sleep 1
}


##################
# STEP FUNCTIONS #
##################

# Initialize array $STEPS()
# OUTPUT
#	$steps()
function initSteps ()
{
	steps+=("1. PNGVIEW")
	steps+=("	1a. Remove PNGVIEW binary			[ waiting...  ]")
	steps+=("2. IMAGEMAGICK")
	steps+=("	2a. Remove IMAGEMAGICK				[ waiting...  ]")
	steps+=("3. SAVESTATE_SELECTOR")
	steps+=("	3a. Remove SAVESTATE_SELECTOR files		[ waiting...  ]")
	steps+=("	3b. Remove SAVESTATE_SELECTOR menu item		[ waiting...  ]")
	steps+=("4. RUNCOMMAND")
	steps+=("	4a. Remove call from RUNCOMMAND-ONSTART		[ waiting...  ]")
	steps+=("5. Finalizing")
	steps+=("	5a. Remove UNINSTALL script			[ waiting...  ]")
}

# Update item of $STEPS() and show updated progress dialog
# INPUT
#	1 > Number of step to update
#	2 > New status for step
#	3 > Percentage to show in progress dialog
#	$steps()
# OUTPUT
#	$steps()
function updateStep ()
{
	local step="$1"
	local newStatus="$2"
	local percent="$3"
	local oldline
	local newline
	
	# translate and colorize $NEWSTATUS
	case "${newStatus}" in
		"waiting")     newStatus="[ ${NORMAL}WAITING...${NORMAL}  ]"  ;;
		"in progress") newStatus="[ ${NORMAL}IN PROGRESS${NORMAL} ]"  ;;
		"done")        newStatus="[ ${GREEN}DONE${NORMAL}        ]"  ;;
		"found")       newStatus="[ ${GREEN}FOUND${NORMAL}       ]"  ;;
		"not found")   newStatus="[ ${RED}NOT FOUND${NORMAL}   ]"  ;;
		"created")     newStatus="[ ${GREEN}CREATED${NORMAL}     ]"  ;;
		"failed")      newStatus="[ ${RED}FAILED${NORMAL}      ]"  ;;
		"skipped")     newStatus="[ ${YELLOW}SKIPPED${NORMAL}     ]"  ;;
		*)             newStatus="[ ${RED}UNDEFINED${NORMAL}   ]"  ;;
	esac
	
	# search $STEP in $STEPS
	for ((i=0; i<${#steps[*]}; i++))
	do
		if [[ ${steps[i]} =~ .*$step.* ]]
		then
			# update $STEP with $NEWSTATUS
			oldline="${steps[i]}"
			oldline="${oldline%%[*}"
			newline="${oldline}${newStatus}"
			steps[i]="${newline}"
			
			break
		fi
	done
	
	# show progress dialog
	dialogShowProgress ${percent}
}

# Show summary dialog
function dialogShowSummary ()
{
	dialog \
		--backtitle "${backtitle}" \
		--title "Summary" \
		--colors \
		--no-collapse \
		--cr-wrap \
		--yesno \
			"\n${GREEN}All done!${NORMAL}\n\nReboot now?" 25 90
	
	case $? in
		0) sudo shutdown -r now  ;;
	esac
}

#########################
# UNINSTALLER FUNCTIONS #
#########################

# Uninstaller
function uninstaller ()
{
	initSteps
	dialogShowProgress 0
	
	saveRemote
	
	1PNGVIEW
	2IMAGEMAGICK
	3SAVESTATE_SELECTOR
	4RUNCOMMAND
	5Finalize
	
	dialogShowSummary
}

function 1PNGVIEW ()
{	
	log 3 "1 START"
# 1a. Remove PNGVIEW binary
	log 3 "1a START"
	updateStep "1a" "in progress" 0
	
	if [ -f /usr/bin/pngview ]
	then
		{ #try
			sudo rm /usr/bin/pngview >> "${log}" &&
			sudo rm /usr/lib/libraspidmx.so.1 >> "${log}" &&
			log 3 "1a DONE" &&
			updateStep "1a" "done" 16
		} || { # catch
			log 3 "1a ERROR" &&
			updateStep "1a" "failed" 0 &&
			exit
		}
	else
		log 3 "1a NOT FOUND" &&
		updateStep "1a" "not found" 16
	fi
	
	log 3 "1 DONE"
}

function 2IMAGEMAGICK ()
{
	log 3 "2 START"
	
# 2a. Remove IMAGEMAGICK binary
	log 3 "2a START"
	updateStep "2a" "in progress" 16
	
	if [ -f /usr/bin/convert ]
	then
		{ # try
			sudo apt-get --yes remove imagemagick* >> "${log}" &&
			log 3 "2a DONE" &&
			updateStep "2a" "done" 32
		} || { # catch
			log 3 "2a ERROR" &&
			updateStep "2a" "failed" 16 &&
			exit
		}
	else
		log 3 "2a NOT FOUND"
		updateStep "2a" "not found" 32
	fi
	
	log 3 "2 DONE"
}

function 3SAVESTATE_SELECTOR ()
{
	log 3 "3 START"
	
# 3a. Remove SAVESTATE_SELECTOR files
	log 3 "3a START"
	updateStep "3a" "in progress" 32
	
	if [ -f ~/scripts/savestate_selector/savestate_selector.sh ]
	then
		{ # try
			sudo rm -f ~/scripts/savestate_selector/savestate_selector-install.* >> "${log}" &&
			sudo rm -f ~/scripts/savestate_selector/savestate_selector.* >> "${log}" &&
			log 3 "3a DONE" &&
			updateStep "3a" "done" 48
		} || { # catch
			log 3 "3a ERROR" &&
			updateStep "3a" "failed" 32 &&
			exit
		}
	else
		log 3 "3a NOT FOUND"
		updateStep "3a" "not found" 48
	fi
	
# 3b. Remove SAVESTATE_SELECTOR menu item
	log 3 "3b START"
	updateStep "3b" "in progress" 48
	
	local found=0
		
	if [[ $(xmlstarlet sel -t -v "count(/gameList/game[path='./savestate_selector-redirect.sh.sh'])" ~/.emulationstation/gamelists/retropie/gamelist.xml) -ne 0 ]]
	then
		found=$(($found + 1))
		
		log 3 "3b XML FOUND"
		
		xmlstarlet ed \
			--inplace \
			--delete "//game[path='./savestate_selector-redirect.sh']" \
			~/.emulationstation/gamelists/retropie/gamelist.xml
			
		log 3 "3b XML REMOVED"
	else
		log 3 "3b XML NOT FOUND"
	fi
	
	if [ -f ~/RetroPie/retropiemenu/savestate_selector-redirect.sh ]
	then
		found=$(($found + 1))
		
		log 3 "3b FILE FOUND"
		
		sudo rm ~/RetroPie/retropiemenu/savestate_selector-redirect.sh >> "${log}"
		sudo rm ~/scripts/savestate_selector/savestate_selector-menu.sh >> "${log}"
		
		log 3 "3b FILE REMOVED"
	else
		log 3 "3b FILE NOT FOUND"
	fi
	
	case $found in
		0) updateStep "3b" "not found" 64  ;;
		1) updateStep "3b" "done" 64		;;
		2) updateStep "3b" "done" 64  ;;
	esac
	
	log 3 "DONE"
}

function 4RUNCOMMAND ()
{
	log 3 "4 START"
	
# 4a. Remove call from RUNCOMMAND-ONSTART
	log 3 "4a START"
	updateStep "4a" "in progress" 64
	
	if [[ $(grep -c "~/scripts/savestate_selector/savestate_selector.sh" /opt/retropie/configs/all/runcommand-onstart.sh) -gt 0 ]]
	then
	{ #try
		sed -i "/~\/scripts\/savestate_selector\/savestate_selector.sh /d" /opt/retropie/configs/all/runcommand-onstart.sh &&
		log 3 "4a DONE" &&
		updateStep "4a" "done" 80
	} || { # catch
		log 3 "4a ERROR" &&
		updateStep "4a" "failed" 64
	}
	else
		log 3 "4a NOT FOUND"
		updateStep "4a" "not found" 80
	fi
}

function 5Finalize ()
{
	log 3 "5 START"

# 8a. Remove UNINSTALL script
	log 3 "5a START"
	updateStep "5a" "in progress" 80
	
	# move LOGFILE to HOME
	mv ~/scripts/savestate_selector/savestate_selector-uninstall.log ~
	
	# remove savestate_selector directory
	rm -rf ~/scripts/savestate_selector
	
	log 3 "5a DONE"
	updateStep "8a" "done" 100
	
	log 3 "5 DONE"
}


########
# MAIN #
########

uninstaller