#!/bin/bash

ARGS=("$@")

XCODE_DIR="/Applications/Xcode.app"
export DEVELOPER_DIR="${XCODE_DIR}/Contents/Developer"

XCODE_VERSION=$(defaults read /Applications/Xcode.app/Contents/version.plist CFBundleShortVersionString)

if [ ${XCODE_VERSION:0:1} == "5" ]; then
	CRASH="${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer/Library/PrivateFrameworks/DTDeviceKitBase.framework/Versions/Current/Resources/symbolicatecrash"
else
	CRASH="${XCODE_DIR}/Contents/SharedFrameworks/DTDeviceKitBase.framework/Versions/Current/Resources/symbolicatecrash"
fi

function checkUUIDAndExec()
{
	LOG_PATH=$1
	APP_PATH=$2

	if [ $(echo "$APP_PATH" | grep "\.app\.dsym") ]; then
		# Find raw UUID when file is .app.dsym
		APP_UUID=$(dwarfdump --uuid $APP_PATH)
	elif [ $(echo "$APP_PATH" | grep "\.app") ]; then
		# Find raw UUID when file is .app
		# Find executable file name
		for i in $(ls "$APP_PATH"); do
			if [ $(echo "$i" | grep "\.") ]; then
				continue
			elif [ $(echo "$i" | grep "PkgInfo") ]; then
				continue
			elif [ $(echo "$i" | grep "_CodeSignature") ]; then
				continue
			else
				EXEC_NAME=$i
			fi
		done
		if [ "$EXEC_NAME"x = x ]; then
			echo "App name not found"
		fi
		APP_UUID=$(dwarfdump --uuid "$APP_PATH/$EXEC_NAME")
	else
		echo "App path $APP_PATH is not valid"
		return
	fi

	# Extract UUID from raw data
	for i in $(echo "$APP_UUID" | grep -Eo "UUID: [0-9a-fA-F\-]+ "); do
		if [[ "$i" = "UUID:" ]]; then
			continue
		else
			# Execute if lowercase UUID is found in crash log
			UUID=$(echo "${i//-/}" | tr 'A-F' 'a-f')
			if [[ $(grep "$UUID" "$LOG_PATH") ]]; then
				$CRASH -v $ARGS
				break
			else
				echo "UUID is not matched"
			fi
		fi
	done
}

checkUUIDAndExec $1 $2
