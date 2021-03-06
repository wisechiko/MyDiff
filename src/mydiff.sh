#!/bin/bash

# ==============================================================================
# Name    : MyDiff
# Version : 1.00 
# Author  : Puydoyeux Vincent
# Date    : 06/12/2012 
# OS      : Tested on --> Linux Fedora 17
#		      --> Linux Debian Squeeze
#		      --> Mac OSX Snow Leopard (Darwin)
# Shell   : Bash
# Note    : Python is used to display the elapsed time used by the script 
# ===============================================================================



# ================================================================================
# Printing functions
# ================================================================================

# Colors
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
WHITE='\033[37m'

# Display the help menu
function PrintUsage() {
	printf "$GREEN
Usage : ./mydiff.sh -s <src dir> -d <dst dir> [-m <comparison mode] [-c <comparison flags>] [-e <skip items>] [-f <file filter>] [-v <verbose level>] [-S] [-h]

    -h                      = display this help
    -s <src dir>            = source directory
    -d <dst dir>            = destination directory
    -m <comparison mode>    = algorithm used to analysed directories
         iterative
         recursive
         Default : \"recursive\"
    -c <comparison flags>   = properties to compare :
         d = diff
         m = md5
         p = permission (and user/group)
         t = last modification date
         Use a list of flags separated by a space; e.g. : \"d p m\"
         Default : \"d\"
    -e <skip items>         = list of items to skip
         e.g. : -e \"\.txt$ logs\"
    -f <file filter>        = file pattern to find
         e.g. : -f \"*.txt;*.log\"
    -l <output file>
	 Default : \"myDiff.log\"
    -v <verbose level>      = verbose level
         0 = display nothing
         1 = display entity name if different
         2 = display differences details
         3 = display all tests
         Default : \"1\"
    -S			   = synchronize dst from src
"
}

# Display errors depending of the defined verbose level
function PrintMsg() {
	local level=$1
	local msg=$2

	if [ $level -le $VERBOSE_LEVEL ]
	then
		printf "$msg\n"
	fi
}

# Write a message in a log file.
function LogDiff() {
	local msg=$1

	# First call to the function => insert an header in the log file
	if [ $LOG_NEW_ENTRY -eq 1 ]
	then
		LOG_NEW_ENTRY=0
		echo "--------------------------------------------------------------" >> $LOG_FILE
		echo -n "Date : " >> $LOG_FILE
		echo `date` >> $LOG_FILE
		echo "Source directory : $DIRPATH_SRC" >> $LOG_FILE
		echo "Destination directory : $DIRPATH_DST" >> $LOG_FILE
		echo "--------------------------------------------------------------" >> $LOG_FILE
		echo "" >> $LOG_FILE
	fi

	printf "$msg\n" >> $LOG_FILE
}



# ================================================================================
# Comparison functions
# ================================================================================

# Synchronize two entities (the content and attributes synchronized depend of the command line paramters)
function DoSynchronize() {
	local src=$1
	local dst=$2
	local perm=`GetPermissions $src`
	local userOwner=`GetOwnerUser $src`
	local groupOwner=`GetOwnerGroup $src`
	local lastModifiedDate=`GetLastModifiedDate $src`
	local merge=""
  	local target=""

  	# the source entity is a directory	
	if [ -d $src ]
	then
		# the destination directory does not exist
		if [ ! -d $dst ]
		then
      			rm $dst 2>/dev/null # src entity is a directory and dst entity is a file ==> delete dst file
			mkdir $dst	
		fi
	elif [ -f $src ] # the source entity is a regular file
  	then
    		# the destination file does not exist
		if [ ! -f $dst ]
		then
      			rm -r $dst 2>/dev/null # src entity is a file and dst entity is a directory ==> delete dst directory
			touch $dst
		fi
		merge=`echo l | sdiff -o $dst $src $dst 2>/dev/null`
  	elif [ -L $src ] # the source entity is a symlink
  	then
      		rm $dst 2>/dev/null # if the dst symlink exists, delete it
      		target=`GetSymlinkTarget $src` # get the target of the src symlink
      		CreateSymlink $dst $target # create a new dst symlink with the src target
	fi

	# Apply permissions, user and group owner, last modified date on the destination entity if not a symlink 
  	if [ ! -L $dst ]
  	then  
		SetPermissions $dst "777"
	  	SetLastModifiedDate $dst "$lastModifiedDate"
	  	SetOwnerUser $dst $userOwner
	  	SetOwnerGroup $dst $groupOwner
	  	SetPermissions $dst $perm
  	fi
}

# Compare two entities.  Tests depend on the enabled flags (DIFF, MD5, PERM, LAST DATE MODIFIED)
# If the entity is a directory, only the PERM test is done.
# If one of the tests fails, the function returns an error code.
function DoCompare() {
	local res=0
	local src=$1
	local dst=$2

 	# if the flag COMP_DIFF is enabled and src and dst entities are symlinks.
  	# checking symlinks targets and exit the function (no more comparison tests done)
  	if [ $COMP_DIFF -eq 1 ] && [ -L $src ] && [ -L $dst ]
  	then
        	SymlinksCompare $src $dst
        	if [ $? -eq 1 ]
        	then
          		PrintMsg 2 "$BLUE Checking symlinks targets.........................................DIFFERENT\n"
          		LogDiff "Checking symlinks targets.........................................DIFFERENT\n"
          		return 1
        	else
          		PrintMsg 2 "$BLUE Checking symlinks targets.............................................IDENT\n"
          		LogDiff "Checking symlinks targets.............................................IDENT\n"
          		return 0
        	fi
  	fi

	# if the destination entity does not exist
	if [ ! -e $dst ]
	then
		PrintMsg 2 "$BLUE Entity \"$dst\" doesn't exist\n"
		LogDiff "Entity \"$dst\" doesn't exist\n"
		res=1
		return $res
	fi

	# if the flag COMP_DIFF is enabled and src and dst entities are not directories
	if [ $COMP_DIFF -eq 1 ] && [ ! -d $src ] && [ ! -d $dst ]
	then
		DiffCompare $src $dst
	 	if [ $? -eq 1 ]
		then
			PrintMsg 2 "$BLUE Checking diff.....................................................DIFFERENT\n"
			LogDiff "Checking diff.....................................................DIFFERENT\n"
			res=1
		else
			PrintMsg 2 "$BLUE Checking diff.........................................................IDENT\n"
			LogDiff "Checking diff.........................................................IDENT\n"
    		fi
	fi

	# if the flag COMP_MD5 is enabled and src and dst entities are not directories
	if [ $COMP_MD5 -eq 1 ] && [ ! -d $src ] && [ ! -d $dst ]
	then
		MD5Compare $src $dst
		if [ $? -eq 1 ]
		then
			PrintMsg 2 "$BLUE Checking md5......................................................DIFFERENT\n"
			LogDiff "Checking md5......................................................DIFFERENT\n"
			res=1
		else
			PrintMsg 2 "$BLUE Checking md5..........................................................IDENT\n"
			LogDiff "Checking md5..........................................................IDENT\n"
    		fi
	fi

	# if the flag COMP_PERM is enabled or if the src entity is a directory
	if [ $COMP_PERM -eq 1 ] || [ -d $src ]
	then
		PermCompare $src $dst
		if [ $? -eq 1 ]
		then
			PrintMsg 2 "$BLUE Checking rights...................................................DIFFERENT\n"
			LogDiff "Checking rights...................................................DIFFERENT\n"
			res=1
		else
			PrintMsg 2 "$BLUE Checking rights.......................................................IDENT\n"
			LogDiff "Checking rights.......................................................IDENT\n"
    		fi

		UserOwnerCompare $src $dst
		if [ $? -eq 1 ]
		then
			PrintMsg 2 "$BLUE Checking user.....................................................DIFFERENT\n"
			LogDiff "Checking user.....................................................DIFFERENT\n"
			res=1
		else
			PrintMsg 2 "$BLUE Checking user.........................................................IDENT\n"
			LogDiff "Checking user.........................................................IDENT\n"
    		fi

		GroupOwnerCompare $src $dst
		if [ $? -eq 1 ]
		then
			PrintMsg 2 "$BLUE Checking group....................................................DIFFERENT\n"
			LogDiff "Checking group....................................................DIFFERENT\n"	
			res=1
		else
			PrintMsg 2 "$BLUE Checking group........................................................IDENT\n"
			LogDiff "Checking group........................................................IDENT\n"
    		fi
	fi

	# if the flag COMP_DATE is enabled and src and dst entities are not directories
	if [ $COMP_DATE -eq 1 ] && [ ! -d $src ] && [ ! -d $dst ]
	then
		LastModifiedCompare $src $dst
		if [ $? -eq 1 ]
		then
			PrintMsg 2 "$BLUE Checking date.....................................................DIFFERENT\n"
			LogDiff "Checking date.....................................................DIFFERENT\n"
			res=1
		else
			PrintMsg 2 "$BLUE Checking date.........................................................IDENT\n"
			LogDiff "Checking date.........................................................IDENT\n"
    		fi
	fi
	
	return $res
}

# Compare targets between two symlinks
function SymlinksCompare() {
	local res=1
  	local src=$1
  	local dst=$2
  	local target_src=`GetSymlinkTarget $src`
  	local target_dst=`GetSymlinkTarget $dst`

  	if [ "$target_src" == "$target_dst" ]
  	then
  	 	res=0
  	fi
 
  	return $res
}

# Compare the content between two files by using the "diff" command
function DiffCompare() {
	local res=1
	local src=$1
	local dst=$2
	local diff=`diff $src $dst`
	
	if [ ${#diff} -eq 0 ]
	then
		res=0
	else
		PrintMsg 3 "$RED $diff"
		LogDiff "$diff"
	fi
	
	return $res
}

# Check if two files have the same MD5 hash
function MD5Compare() {
	local res=1
	local src=$1
	local dst=$2
	local md5src=""
	local md5dst=""

	# MACINTOSH
	if [ "`uname | grep Darwin`" == "Darwin" ]
	then
		md5src=`md5 $src | cut -d' ' -f4`
		md5dst=`md5 $dst | cut -d' ' -f4`
	else # LINUX
		md5src=`md5sum $src | cut -d' ' -f1`
		md5dst=`md5sum $dst | cut -d' ' -f1`
	fi

	if [ "$md5src" == "$md5dst" ]
	then
		res=0
	else
		PrintMsg 3 "$RED $md5src != $md5dst"
		LogDiff "$md5src != $md5dst"
	fi

	return $res
}

# Compare the permissions between two files
function PermCompare() {
	local res=1
	local src=$1
	local dst=$2
	local permSrc=`GetPermissions $src`
	local permDst=`GetPermissions $dst`

	if [ $permSrc -eq $permDst ]
	then
		res=0
	else
		PrintMsg 3 "$RED $permSrc != $permDst"
		LogDiff "$permSrc != $permDst"
	fi

	return $res
}

# Compare the last modified date between two files
function LastModifiedCompare() {
	local res=1
	local src=$1
	local dst=$2
	local dateModifSrc=`GetLastModifiedDate $src`
	local dateModifDst=`GetLastModifiedDate $dst`

	if [ "$dateModifSrc" ==  "$dateModifDst" ]
	then
		res=0
	else
		PrintMsg 3 "$RED $dateModifSrc != $dateModifDst"
		LogDiff "$dateModifSrc != $dateModifDst"
	fi

	return $res
}

# Compare users owners between two files
function UserOwnerCompare() {
	local res=1
	local src=$1
	local dst=$2
	local userSrc=`GetOwnerUser $src`
	local userDst=`GetOwnerUser $dst`

	if [ "$userSrc" == "$userDst" ]
	then
		res=0
	else
		PrintMsg 3 "$RED $userSrc != $userDst"
		LogDiff "$userSrc != $userDst"
	fi

	return $res
}

# Compare groups owners between two files
function GroupOwnerCompare() {
	local res=1
	local src=$1
	local dst=$2
	local groupSrc=`GetOwnerGroup $src`
	local groupDst=`GetOwnerGroup $dst`

	if [ "$groupSrc" == "$groupDst" ]
	then
		res=0
	else
		PrintMsg 3 "$RED $groupSrc != $groupDst"
		LogDiff "$groupSrc != $groupDst"
	fi

	return $res
}



# ================================================================================
# File/Directory functions
# ================================================================================

# Return the target of a symlink
function GetSymlinkTarget() {
  	local link=$1
  	local target=`readlink $link`

  	echo $target
}

# Create a symlink with a target
function CreateSymlink() {
  	local link=$1
  	local target=$2
  	local cmd=`ln -s $target $link`

  	return $?
}
  
# Return the permissions of a file or directory (numeric format)
function GetPermissions() {
	local entity=$1
	local perm=""

	# MACINTOSH
	if [ "`uname | grep Darwin`" == "Darwin" ]
	then
		perm=`stat -f %Mp%Lp $entity`	
	else # LINUX
		perm=`stat --format %a $entity`
	fi	

	echo $perm
}

# Set given permissions on a file or directory
function SetPermissions() {
	local entity=$1
	local perm=$2
	local res=`chmod $perm $entity`
	
	return $?
}

# Retrun the user owner of a file or directory
function GetOwnerUser() {
	local entity=$1
	local user=""

	# MACINTOSH
	if [ "`uname | grep Darwin`" == "Darwin" ]
	then
		user=`stat -f %Su $entity`
	else # LINUX
		user=`stat --format %U $entity`
	fi

	echo $user
}

# Set a user as the owner of a file or directory
function SetOwnerUser() {
	local entity=$1
	local user=$2
	local res=`chown $user $entity`

	return $?
}

# Return the group owner of a file or directory
function GetOwnerGroup() {
	local entity=$1
	local group=""

	# MACINTOSH
	if [ "`uname | grep Darwin`" == "Darwin" ]
	then
		group=`stat -f %Sg $entity`
	else # LINUX
		group=`stat --format %G $entity`
	fi

	echo $group
}

# Set a group as the owner of a file or directory
function SetOwnerGroup() {
	local entity=$1
	local group=$2
	local res=`chgrp $group $entity`

	return $?
}

#Return the last modified date of a file or directory
function GetLastModifiedDate() {
	local entity=$1
	local modifiedDate=""

	# MACINTOSH
	if [ "`uname | grep Darwin`" == "Darwin" ]
	then
		modifiedDate=`stat -f %Sm $entity`
	else # LINUX
		modifiedDate=`stat --format %y $entity`
	fi
	
	echo "$modifiedDate"
}

# Set a last modified date for a file or directory
function SetLastModifiedDate() {
	local entity=$1
	local modifiedDate="$2"
	local res=""
	local year=""
	local month=""
	local day=""
	local time=""
	local time_hour=""
	local time_min=""
	local time_sec=""

	# MACINTOSH
	if [ "`uname | grep Darwin`" == "Darwin" ]
	then
		modifiedDate=$( echo $modifiedDate | tr "  " " ")
		year=$( echo $modifiedDate | cut -d' ' -f4 )
		month=$( echo $modifiedDate | cut -d' ' -f1 )
		day=$( echo $modifiedDate | cut -d' ' -f2 )

		if [ ${#day} -eq 1 ]
		then
			day="0$day"		
		fi

		case $month in
		'Jan')
			month="01"
			;;
		'Feb')
			month="02"
			;;
		'Mar')
			month="03"
			;;
		'Apr')
			month="04"
			;;
		'May')
			month="05"
			;;
		'Jun')
			month="06"
			;;
		'Jul')
			month="07"
			;;
		'Aug')
			month="08"
			;;
		'Sep')
			month="09"
			;;
		'Oct')
			month="10"
			;;
		'Nov')
			month="11"
			;;
		'Dec')
			month="12"
			;;
		esac
		time_=$( echo $modifiedDate | cut -d' ' -f3 )
		time_hour=$( echo $time_ | cut -d: -f1 )
		time_min=$( echo $time_ | cut -d: -f2 )
		time_sec=$( echo $time_ | cut -d: -f3 )
		res=`touch -mt $year$month$day$time_hour$time_min.$time_sec $entity`
	else # LINUX
		res=`touch -d "$modifiedDate" $entity`
	fi

	return $?
}



# ================================================================================
# Utils functions
# ================================================================================

# Check if the given directory ends with a slash and then remove it
function  RemoveEndSlash() {
	local dir=$1
	
	if [ ${dir#${dir%?}} == '/' ]
	then
		dir=${dir:0:${#dir} - 1}
	fi
	echo $dir
}

# Check if the DIRPATH_SRC and DIRPATH_DST variables are initialized and directories exist
function CheckInitSrcDestVar() {

	if [ "$DIRPATH_SRC" == "" ] || [ "$DIRPATH_DST" == "" ] || [ ! -d $DIRPATH_SRC ] || [ ! -d $DIRPATH_DST ]
	then	
		PrintMsg 3 "$RED Missing source directory\n"
		PrintMsg 3 "$RED Missing destination directory\n"
		LogDiff "Missing source directory\n"
		LogDiff "Missing destination directory\n"
		LogDiff "********************************************************************************\n"
		PrintUsage
		tput sgr0

		exit $ERROR_UNINITIALIZED_VARIABLE
	fi
}

# Return the file extension (ex: '.txt' )
function GetFileExtension() {
	local file=$1

	echo .${file#*.}
}

# Check if the entity extension is in the exclusion list
# Returns 1 if the extension is in the list, else 0
function CheckExtensionExclusions() {
	local src=$1
	local res=0

	if [ "$EXCLUDE_EXT" != "" ]
	then
		for ext in $EXCLUDE_EXT
		do
			# compare the entity extension with each extension in the list
			if [ `GetFileExtension $src_entity` == $ext ]
			then
				PrintMsg 3 "$RED \"$src\" will not be checked (extension exclusion)\n"
				PrintMsg 1 "$WHITE\n********************************************************************************\n"
				LogDiff "\"$src\" will not be checked (extension exclusion)\n"
				LogDiff "********************************************************************************\n"
				res=1
				return $res
			fi
		done
	fi
	return $res
}

# Check if the entity pathname contains a pattern from the exlusion list
# Returns 0 if a pattern was found, else 1 
function CheckPathnameExclusions() {
	local src=$1
	local res=1
	local tmp=""

	if [ "$EXCLUDE_NAME" != "" ]
	then
		# for each pattern in the exlusion list
		for keyword in $EXCLUDE_NAME
		do
			# grep 'pattern' on the entity pathname
			tmp=`echo $src | grep $keyword`
			res=$?
			if [ $res -eq 0 ]
			then
				PrintMsg 3 "$RED \"$src\" will not be checked (keyword exclusion)\n"
				PrintMsg 1 "$WHITE\n********************************************************************************\n"
				LogDiff "\"$src\" will not be checked (keyword exclusion)\n"
				LogDiff "********************************************************************************\n"
				return $res
			fi
		done
	fi
	return $res
}

# Check if the entity extension is in the filters list
# Returns 1 if the extension is in the list, else 0
function CheckExtensionFilters() {
	local src=$1
	local res=0

	if [ "$FILTER" != "" ]
	then
		for ext in $FILTER
		do
			if [ `GetFileExtension $src` == $ext ]
			then
				res=1
			fi
		done
	fi

	if [ $res -eq 0 ]
	then
		PrintMsg 3 "$RED \"$src\" will not be checked (extension filter)\n"
		PrintMsg 1 "$WHITE\n********************************************************************************\n"
		LogDiff "\"$src\" will not be checked (extension filter)\n"
		LogDiff "********************************************************************************\n"
	fi

	return $res
}

# Recursive function to explore a given source directory and compare it with a destination directory
# Returns 0 if DIRPATH_SRC and DIRPATH_DST are similar, else 1
function RecursiveDiff() {
	local res=0
	local ret=0
	local extExclusions=0
	local pathnameExclusions=0
	local extFilters=0
	local src=$1
	local dst=$2
	local dst_entity=""

	# for each entity in the src directory
	for src_entity in $src/*
	do
		# deduction of the dst entity from the src entity path
		dst_entity=$dst${src_entity:${#DIRPATH_SRC}:${#src_entity}} 
	
		# case 1 : the entity is a directory (recursive call)
		if [ -d $src_entity ]
		then
			CheckPathnameExclusions $src_entity
			pathnameExclusions=$?
			# if the entity does not contain a pattern from the exclusion list
			if [ $pathnameExclusions -ne 0 ]
			then
				# comparison
				DoCompare $src_entity $dst_entity
				res=$?
				# if src and dst are different
				if [ $res -eq 1 ] 
				then
					if [ $SYNCHRONIZE -eq 1 ]
					then
						DoSynchronize $src_entity $dst_entity
					fi
					PrintMsg 1 "$YELLOW Directories \"$src_entity\" and \"$dst_entity\" are different\n"
					LogDiff "Directories \"$src_entity\" and \"$dst_entity\" are different\n"
					ret=$ERROR_MISMATCH
				else
					PrintMsg 1 "$YELLOW Directories \"$src_entity\" and \"$dst_entity\" are identical\n"
					LogDiff "Directories \"$src_entity\" and \"$dst_entity\" are identical\n"
				fi
				PrintMsg 1 "$WHITE********************************************************************************\n"
				LogDiff "********************************************************************************\n"
			fi
			# recursive function call from the current sub directory
			RecursiveDiff $src_entity $dst



		# case 2 : the entity is not a directory
    		elif [ -e $src_entity ] || [ -L $src_entity ]
    		then
			CheckExtensionExclusions $src_entity
			extExclusions=$?
			CheckPathnameExclusions $src_entity
			pathnameExclusions=$?

			# if the file extension is not in the exclusion list and no pattern
			if [ $extExclusions -eq 0 ] && [ $pathnameExclusions -ne 0 ]
			then
				# if filters have been set
				if [ "$FILTER" != "" ]
				then
					CheckExtensionFilters $src_entity
					extFilters=$?
					# if the entity extension is in the filters list
					if [ $extFilters -eq 1 ]
					then
						# comparison
						DoCompare $src_entity $dst_entity
						res=$?
					fi
				else
					# no filter defined
					DoCompare $src_entity $dst_entity
					res=$?
				fi

				# if src and dst entities are different
				if [ $res -eq 1 ]
				then
					if [ $SYNCHRONIZE -eq 1 ]
					then
						DoSynchronize $src_entity $dst_entity
					fi
					PrintMsg 1 "$YELLOW Files \"$src_entity\" and \"$dst_entity\" are different\n"
					LogDiff "Files \"$src_entity\" and \"$dst_entity\" are different\n"
					PrintMsg 1 "$WHITE********************************************************************************\n"
					LogDiff "********************************************************************************\n"
					ret=$ERROR_MISMATCH
				elif [ "$FILTER" == "" ] || [ $extFilters -eq 1 ]
				then
					PrintMsg 1 "$YELLOW Files \"$src_entity\" and \"$dst_entity\" are identical\n"
					LogDiff "Files \"$src_entity\" and \"$dst_entity\" are identical\n"
					PrintMsg 1 "$WHITE********************************************************************************\n"
					LogDiff "********************************************************************************\n"
				fi
			fi
		fi

		res=0
		extFilters=0
	done

	return $ret
}

# Iterative function to explore a given source directory and compare it with a destination directory
# Returns 0 if DIRPATH_SRC and DIRPATH_DST are similar, else 1
function IterativeDiff() {
	local res=0
	local ret=0
	local extExclusions=0
	local pathnameExclusions=0
	local extFilters=0
	local src=$1
	local dst=$2
	local dst_entity=""

	# list all directories in the source directory
	for src_entity in `find $src -type d`
	do
		if [ "$src_entity" != "$src" ]
		then
			# deduction of the dst entity from the src entity path
			dst_entity=$dst${src_entity:${#DIRPATH_SRC}:${#src_entity}}

			CheckPathnameExclusions $src_entity
			pathnameExclusions=$?

			# if the entity does not contain a pattern from the exclusion list
			if [ $pathnameExclusions -ne 0 ]
			then
				# comparison
				DoCompare $src_entity $dst_entity
				res=$?	
				# if src and dst are different
				if [ $res -eq 1 ] 
				then
					if [ $SYNCHRONIZE -eq 1 ]
					then
						DoSynchronize $src_entity $dst_entity
					fi
					PrintMsg 1 "$YELLOW Directories \"$src_entity\" and \"$dst_entity\" are different\n"
					LogDiff "Directories \"$src_entity\" and \"$dst_entity\" are different\n"
					ret=$ERROR_MISMATCH
				else
					PrintMsg 1 "$YELLOW Directories \"$src_entity\" and \"$dst_entity\" are identical\n"
					LogDiff "Directories \"$src_entity\" and \"$dst_entity\" are identical\n"
				fi
				PrintMsg 1 "$WHITE********************************************************************************\n"
				LogDiff "********************************************************************************\n"
			fi
		fi
	done

	# list all regular files and symlinks in the source directory
	for src_entity in `find $src -type f && find $src -type l`
	do
		if [ "$src_entity" != "$src" ]
		then
			# deduction of the dst entity from the src entity path
			dst_entity=$dst${src_entity:${#DIRPATH_SRC}:${#src_entity}}

			CheckExtensionExclusions $src_entity
			extExclusions=$?

			CheckPathnameExclusions $src_entity
			pathnameExclusions=$?

			# if the file extension is not in the exclusion list and no pattern
			if [ $extExclusions -eq 0 ] && [ $pathnameExclusions -ne 0 ]
			then
				# if filters have been set
				if [ "$FILTER" != "" ]
				then
					CheckExtensionFilters $src_entity
					extFilters=$?
					# if the entity extension is in the filters list
					if [ $extFilters -eq 1 ]
					then
						# comparison
						DoCompare $src_entity $dst_entity
						res=$?
					fi
				else
					# no filter defined
					DoCompare $src_entity $dst_entity
					res=$?
				fi

				# if src and dst entities are different
				if [ $res -eq 1 ]
				then
					if [ $SYNCHRONIZE -eq 1 ]
					then
						DoSynchronize $src_entity $dst_entity
					fi
					PrintMsg 1 "$YELLOW Files \"$src_entity\" and \"$dst_entity\" are different\n"
					LogDiff "Files \"$src_entity\" and \"$dst_entity\" are different\n"
					ret=$ERROR_MISMATCH
					PrintMsg 1 "$WHITE********************************************************************************\n"
					LogDiff "********************************************************************************\n"
				elif [ "$FILTER" == "" ] || [ $extFilters -eq 1 ]
				then
					PrintMsg 1 "$YELLOW Files \"$src_entity\" and \"$dst_entity\" are identical\n"
					LogDiff "Files \"$src_entity\" and \"$dst_entity\" are identical\n"
					PrintMsg 1 "$WHITE********************************************************************************\n"
					LogDiff "********************************************************************************\n"
				fi
			fi 
		fi
		res=0
		extFilters=0
	done

	return $ret
}



# ================================================================================
# Beginning of script
# ================================================================================

############################# ARGUMENTS DEFAULT VALUES ###############################
DIRPATH_SRC=""
DIRPATH_DST=""
ANALYSIS_MODE=1
COMP="d"
COMP_DIFF=1
COMP_MD5=0
COMP_PERM=0
COMP_DATE=0
SYNCHRONIZE=0
EXCLUDE=""
EXCLUDE_EXT=""
EXCLUDE_NAME=""
FILTER=""
LOG_FILE="myDiff.log"
LOG_NEW_ENTRY=1

VERBOSE_LEVEL=1
VERBOSE_LEVEL_ERROR=0
VERBOSE_LEVEL_DIFF=1
VERBOSE_LEVEL_DIFF_DETAIL=2
VERBOSE_LEVEL_ALL=3

SUCCESS=0
ERROR_INVALID_OPTION=1
ERROR_UNINITIALIZED_VARIABLE=2
ERROR_MISMATCH=3



############################# ARGUMENTS ANALYSIS ###############################

# Options parser and arguments initialization
while getopts "s:d:m:c:e:f:l:v:Sh" opt
do
	case $opt in
	s)	# source directory
		DIRPATH_SRC=`RemoveEndSlash $OPTARG`
		;;

	d)	# destination directory
		DIRPATH_DST=`RemoveEndSlash $OPTARG`
		;;
  
	m)	# analysis mode
		case $OPTARG in
		'iterative')
			ANALYSIS_MODE=0
			;;
		'recursive')
			ANALYSIS_MODE=1
			;;
		?)
			PrintMsg 3 "$RED Option '-m' has an invalid parameter\n"
			LogDiff "Option '-m' has an invalid parameter\n"
			PrintUsage
			tput sgr0
			exit $ERROR_INVALID_OPTION
		esac
		;;

	c)	# comparison mode
		for flag in $( echo $OPTARG | tr " " " " ) 
		do
			case $flag in
			d)
				COMP_DIFF=1
				;;
			m)
				COMP_MD5=1
				;;
			p)
				COMP_PERM=1
				;;
			t)
				COMP_DATE=1
				;;
			?)
				PrintMsg 3 "$RED Option '-c' has an invalid parameter\n"
				LogDiff "Option '-c' has an invalid parameter\n"
				PrintUsage
				tput sgr0
				exit $ERROR_INVALID_OPTION
			esac
		done
		;;

	e)	# exclude filters
		EXCLUDE=$OPTARG
		for ext in $(echo $OPTARG | tr " " " ")
		do
			if [ ${ext:0:1} == '\\' ] && [ ${ext:${#ext} - 1:${#ext}} == "$" ]
			then
				EXCLUDE_EXT="$EXCLUDE_EXT${ext:1:${#ext} - 2} "
			else
				EXCLUDE_NAME="$EXCLUDE_NAME$ext "
			fi
		done
		;;

	f)	# include filters
		for ext in $(echo $OPTARG | tr ";" " ")
		do
			ext=$(echo $ext | tr "*" " ")
			ext=${ext[0]}
			FILTER="$FILTER$ext "
	 	done	
		;;

	l)	# log file name
		LOG_FILE=$OPTARG
		;;

	v)	# verbose levels
		case $OPTARG in
		0)
			VERBOSE_LEVEL=$VERBOSE_LEVEL_ERROR
			;;
		1)
			VERBOSE_LEVEL=$VERBOSE_LEVEL_DIFF
			;;
		2)
			VERBOSE_LEVEL=$VERBOSE_LEVEL_DIFF_DETAIL
			;;
		3)
			VERBOSE_LEVEL=$VERBOSE_LEVEL_ALL
			;;
		?)
			PrintMsg 3 "$RED Option '-v' has an invalid verbose level\n"
			LogDiff "Option '-v' has an invalid verbose level\n"
			PrintUsage
			tput sgr0
			exit $ERROR_INVALID_OPTION
		esac
		;;

	S)	# synchronize
		SYNCHRONIZE=1
		;;

	h)	# help menu
		PrintUsage
		tput sgr0
		exit $SUCCESS
		;;

	?)	# unknown option
	 	PrintMsg 3 "$RED Option is not valid\n"
		LogDiff "Option is not valid\n"
		PrintUsage
		tput sgr0
		exit $ERROR_INVALID_OPTION
	esac
done



############################# MAIN  ###############################
ret=0

# get starting time
start_time=`python -c 'import time; print time.time()'`

# check DIRPATH_SRC and DIRPATH_DST
CheckInitSrcDestVar

# analysis mode
if [ $ANALYSIS_MODE -eq 1 ]
then
	RecursiveDiff $DIRPATH_SRC $DIRPATH_DST
	ret=$?
	PrintMsg 0 "$YELLOW # =========================================================================== #"
	PrintMsg 0 "$YELLOW #                                   MyDiff                                    #"
	PrintMsg 0 "$YELLOW # =========================================================================== #\n"
	PrintMsg 0 "$YELLOW Mode         : Recursive"
else
	IterativeDiff $DIRPATH_SRC $DIRPATH_DST
	ret=$?
	PrintMsg 0 "$YELLOW # =========================================================================== #"
	PrintMsg 0 "$YELLOW #                                   MyDiff                                    #"
	PrintMsg 0 "$YELLOW # =========================================================================== #\n"
	PrintMsg 0 "$YELLOW Mode         : Iterative"
fi

# Comparison between src and dst result
if [ $ret -eq $ERROR_MISMATCH ]
then
	PrintMsg 0 "$YELLOW Comparison   : $DIRPATH_SRC and $DIRPATH_DST are different"
else
	PrintMsg 0 "$YELLOW Comparison   : $DIRPATH_SRC and $DIRPATH_DST are identical"
fi

# display syncing state
if [ $SYNCHRONIZE -eq 1 ]
then
	PrintMsg 0 "$YELLOW Syncing      : ON"
else
	PrintMsg 0 "$YELLOW Syncing      : OFF"
fi

# get ending time
end_time=`python -c 'import time; print time.time()'`

# display elapsed time
PrintMsg 0 "$YELLOW Elapsed time : $( echo $end_time - $start_time | bc ) seconds\n"

# reset the default color of the terminal
tput sgr0

exit $ret

