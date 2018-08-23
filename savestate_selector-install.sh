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


# global variables
url="https://raw.githubusercontent.com/Jandalf81/savestate_selector"
branch="master"

backtitle="SAVESTATE_SELECTOR installer (https://github.com/Jandalf81/savestate_selector)"

declare -a steps

logLevel=3
log=~/scripts/savestate_selector/savestate_selector-install.log


##################
# WELCOME DIALOG #
##################
dialog \
	--backtitle "${backtitle}" \
	--title "Welcome" \
	--colors \
	--no-collapse \
	--cr-wrap \
	--yesno \
		"\nThis script will configure RetroPie so that you'll be able to select and start a savestate directly after selecting a ROM.\n\nAre you sure you wish to continue?" \
	26 90 2>&1 > /dev/tty \
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

# Warn the user if they are using the BETA branch
function dialogBetaWarning ()
{
	dialog \
		--backtitle "${backtitle}" \
		--title "Beta Warning" \
		--colors \
		--no-collapse \
		--cr-wrap \
		--yesno \
			"\n${RED}${UNDERLINE}WARNING!${NORMAL}\n\nYou are about to install a beta version!\nAre you ${RED}REALLY${NORMAL} sure you want to continue?" \
		10 50 2>&1 > /dev/tty \
    || exit
}

function buildProgress ()
{
	progress=""
	
	for ((i=0; i<=${#steps[*]}; i++))
	do
		progress="${progress}${steps[i]}\n"
	done
}

function dialogShowProgress ()
{
	local percent="$1"
	
	buildProgress
	
	clear
	
	echo "${percent}" | dialog \
		--stdout \
		--colors \
		--no-collapse \
		--cr-wrap \
		--backtitle "${backtitle}" \
		--title "Installer" \
		--gauge "${progress}" 36 90 0 \
		2>&1 > /dev/tty
		
	sleep 1
}

function dialogShowSummary ()
{
	dialog \
		--backtitle "${backtitle}" \
		--title "Summary" \
		--colors \
		--no-collapse \
		--cr-wrap \
		--yesno \
			"\n${GREEN}All done!${NORMAL}\n\nReboot now?" \
		28 90 2>&1 > /dev/tty
	
	case $? in
		0) sudo shutdown -r now  ;;
	esac
}

function initSteps ()
{
	steps+=("1. PNGVIEW")
	steps+=("	1a. Test for PNGVIEW binary			[ waiting...  ]")
	steps+=("	1b. Download PNGVIEW source			[ waiting...  ]")
	steps+=("	1c. Compile PNGVIEW				[ waiting...  ]")
	steps+=("2. IMAGEMAGICK")
	steps+=("	2a. Test for IMAGEMAGICK			[ waiting...  ]")
	steps+=("	2b. apt-get install IMAGEMAGICK			[ waiting...  ]")
	steps+=("3. SAVESTATE_SELECTOR")
	steps+=("	3a. Download SAVESTATE_SELECTOR files		[ waiting...  ]")
	steps+=("	3b. Create SAVESTATE_SELECTOR menu item		[ waiting...  ]")
	steps+=("	3c. Configure SAVESTATE_SELECTOR		[ waiting...  ]")
	steps+=("4. RUNCOMMAND")
	steps+=("	4a. Add call to RUNCOMMAND-ONSTART		[ waiting...  ]")
	steps+=("5. Finalizing")
	steps+=("	5a. Save configuration				[ waiting...  ]")
}

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


#######################
# INSTALLER FUNCTIONS #
#######################


# Installer
function installer ()
{
	initSteps
	dialogShowProgress 0
	
	1PNGVIEW
	2IMAGEMAGICK
	3SAVESTATE_SELECTOR
	
	dialogShowSummary
}


function 1PNGVIEW ()
{
# 1a. Testing for PNGVIEW binary
	updateStep "1a" "in progress" 20
	
	1aTestPNGVIEW
	if [[ $? -eq 0 ]]
	then
		updateStep "1a" "found" 25
		updateStep "1b" "skipped" 30
		updateStep "1c" "skipped" 35
	else
		updateStep "1a" "not found" 25

# 1b. Getting PNGVIEW source
		updateStep "1b" "in progress" 25
		
		1bGetPNGVIEWsource
		if [[ $? -eq 0 ]]
		then
			updateStep "1b" "done" 30
			
# 1c. Compiling PNGVIEW
			updateStep "1c" "in progress" 30
			
			1cCompilePNGVIEW
			if [[ $? -eq 0 ]]
			then
				updateStep "1c" "done" 35
			else
				updateStep "1c" "failed" 30
				exit
			fi
		else
			updateStep "1b" "failed" 25
			exit
		fi
	fi
}

# Checks if PNGVIEW is installed
# RETURN
#	0 > PNGVIEW is installed
#	1 > PNGVIEW is not installed
function 1aTestPNGVIEW ()
{
	log 3 "START"
	
	if [ -f /usr/bin/pngview ]
	then
		log 3 "FOUND"
		return 0
	else
		log 3 "NOT FOUND"
		return 1
	fi
}

# Gets PNGVIEW source
# RETURN
#	0 > source downloaded and unzipped
#	1 > no source downloaded, removed temp files
function 1bGetPNGVIEWsource ()
{
	log 3 "START"
	
	{ #try
		wget -P ~ https://github.com/AndrewFromMelbourne/raspidmx/archive/master.zip --append-output="${log}" &&
		unzip ~/master.zip -d ~ >> "${log}" &&
		
		log 3 "DONE" &&
	
		return 0
	} || { #catch
		log 3 "ERROR" &&
		
		rm ~/master.zip >> "${log}" &&
		sudo rm -r ~/raspidmx-master >> "${log}" &&
	
		return 1
	}
}

# Compiles PNGVIEW source, moves binaries
# RETURN
#	0 > compiled without errors, moved binaries, removed temp files
#	1 > errors while compiling, removed temp files
function 1cCompilePNGVIEW ()
{
	log 3 "START"
	
	{ #try
		# compile
		# cd ~/raspidmx-master &&
		make --directory=~/raspidmx-master >> "${log}" &&
	
		# move binary files
		sudo mv ~/raspidmx-master/pngview/pngview /usr/bin >> "${log}" &&
		sudo mv ~/raspidmx-master/lib/libraspidmx.so.1 /usr/lib >> "${log}" &&
		sudo chown root:root /usr/bin/pngview >> "${log}" &&
		sudo chmod 755 /usr/bin/pngview >> "${log}" &&
		
		# remove temp files
		rm ~/master.zip >> "${log}" &&
		sudo rm -r ~/raspidmx-master >> "${log}" &&
		
		log 3 "DONE" &&
	
		return 0
	} || { #catch
		log 3 "ERROR" &&
	
		# remove temp files
		rm ~/master.zip >> "${log}" &&
		sudo rm -r ~/raspidmx-master >> "${log}" &&
		
		return 1
	}
}

function 2IMAGEMAGICK ()
{
# 2a. Testing for IMAGEMAGICK
	updateStep "2a" "in progress" 35
	
	2aTestIMAGEMAGICK
	if [[ $? -eq 0 ]]
	then
		updateStep "2a" "found" 40
		updateStep "2b" "skipped" 45
	else
		updateStep "2a" "not found" 40
		
# 2b. Getting IMAGEMAGICK
		updateStep "2b" "in progress" 40
		2bInstallIMAGEMAGICK
		if [[ $? -eq 0 ]]
		then
			updateStep "2b" "done" 45
		else
			updateStep "2b" "failed" 40
		fi
	fi
}

# Checks is IMAGEMAGICK is installed
# RETURN
#	0 > IMAGEMAGICK is installed
#	1 > IMAGEMAGICK is not installed
function 2aTestIMAGEMAGICK ()
{
	log 3 "START"
	
	if [ -f /usr/bin/convert ]
	then
		log 3 "FOUND"
		return 0
	else
		log 3 "NOT FOUND"
		return 1
	fi
}

# Installs IMAGEMAGICK via APT-GET
# RETURN
#	0 > IMAGEMAGICK has been installed
#	1 > Error while installing IMAGEMAGICK
function 2bInstallIMAGEMAGICK ()
{
	log 3 "START"
	
	sudo apt-get update >> "${log}"
	sudo apt-get --yes install imagemagick >> "${log}"
	
	if [[ $? -eq 0 ]]
	then
		log 3 "DONE"
		return 0
	else
		log 3 "ERROR"
		return 1
	fi
}

function 3SAVESTATE_SELECTOR ()
{
	updateStep "3a" "in progress"
	
	3aDownloadFiles
	if [[ $? -eq 0 ]]
	then
		updateStep "3a" "done" 50
	else
		updateStep "3a" "failed" 45
		exit
	fi
	
# 3b. Creating SAVESTATE_SELECTOR menu item
	updateStep "3b" "in progress" 50
	
	3bCreateSAVESTATE_SELECTORMenuItem
	if [[ $? -eq 0 ]]
	then
		updateStep "3b" "done" 55
	else
		updateStep "3b" "failed" 50
		exit
	fi
}

function 3aDownloadFiles ()
{
	log 3 "START"
	
	# create directory if necessary
	if [ ! -d ~/scripts/savestate_selector ]
	then
		mkdir ~/scripts/savestate_selector >> "${log}"
	fi
	
	{ #try
		# get script files
		wget -N -P ~/scripts/savestate_selector ${url}/${branch}/savestate_selector.sh --append-output="${log}" &&
		wget -N -P ~/scripts/savestate_selector ${url}/${branch}/savestate_selector-menu.sh --append-output="${log}" &&
		wget -N -P ~/scripts/savestate_selector ${url}/${branch}/savestate_selector-uninstall.sh --append-output="${log}" &&
		
		# change mod
		chmod +x ~/scripts/savestate_selector/savestate_selector.sh >> "${log}" &&
		chmod +x ~/scripts/savestate_selector/savestate_selector-menu.sh >> "${log}" &&
		chmod +x ~/scripts/savestate_selector/savestate_selector-uninstall.sh >> "${log}" &&
		
		log 3 "DONE" &&
		
		return 0
	} || { # catch
		log 3 "ERROR" &&
		
		return 1
	}
}

function 3bCreateSAVESTATE_SELECTORMenuItem ()
{
	log 3 "START"
	
	# create redirect script
	printf "#!/bin/bash\n~/scripts/savestate_selector/savestate_selector-menu.sh" > ~/RetroPie/retropiemenu/savestate_selector-redirect.sh
	chmod +x ~/RetroPie/retropiemenu/savestate_selector-redirect.sh
	
	# check if menu item exists
	if [[ $(xmlstarlet sel -t -v "count(/gameList/game[path='./savestate_selector-redirect.sh'])" ~/.emulationstation/gamelists/retropie/gamelist.xml) -eq 0 ]]
	then
		log 3 "NOT FOUND"
			
		xmlstarlet ed \
			--inplace \
			--subnode "/gameList" --type elem -n game -v ""  \
			--subnode "/gameList/game[last()]" --type elem -n path -v "./savestate_selector-redirect.sh" \
			--subnode "/gameList/game[last()]" --type elem -n name -v "SAVESTATE_SELECTOR menu" \
			--subnode "/gameList/game[last()]" --type elem -n desc -v "Launches a menu allowing you to configure savestate_selector or even uninstall it" \
			~/.emulationstation/gamelists/retropie/gamelist.xml
		
		if [[ $? -eq 0 ]]
		then
			log 3 "CREATED"
			return 0
		else
			log 3 "ERROR"
			return 1
		fi
	else
		log 3 "FOUND"
		return 0
	fi
}


########
# MAIN #
########

installer