#!/bin/bash
set -euo pipefail

if [[ $# -lt 4 ]]; then
    printf '%s\n' "Usage: $0 <success-title> <failure-title> <empty-message> <script-path> [args...]" >&2
    exit 64
fi

readonly SUCCESS_TITLE=$1
readonly FAILURE_TITLE=$2
readonly EMPTY_MESSAGE=$3
readonly TARGET_SCRIPT=$4
shift 4

exec /usr/bin/osascript - "${SUCCESS_TITLE}" "${FAILURE_TITLE}" "${EMPTY_MESSAGE}" "${TARGET_SCRIPT}" "$@" <<'APPLESCRIPT'
on joinList(valueList, delimiterText)
    set oldDelimiters to AppleScript's text item delimiters
    set AppleScript's text item delimiters to delimiterText
    set joinedText to valueList as text
    set AppleScript's text item delimiters to oldDelimiters
    return joinedText
end joinList

on buildShellCommand(targetScript, extraArguments)
    set commandParts to {quoted form of "/bin/bash", quoted form of targetScript}
    repeat with currentArgument in extraArguments
        set end of commandParts to quoted form of (contents of currentArgument)
    end repeat
    return my joinList(commandParts, " ")
end buildShellCommand

on successMessage(commandOutput, emptyMessage)
    if commandOutput is "" then
        return emptyMessage
    end if
    return "Completed actions:" & return & return & commandOutput
end successMessage

on failureMessage(commandOutput)
    if commandOutput is "" then
        return "The command did not produce any output."
    end if
    return "The command reported the following before it failed:" & return & return & commandOutput
end failureMessage

on showDialog(dialogTitle, dialogMessage, iconName)
    try
        tell current application to activate
    end try

    try
        if iconName is "stop" then
            display dialog dialogMessage with title dialogTitle buttons {"OK"} default button "OK" with icon stop
        else
            display dialog dialogMessage with title dialogTitle buttons {"OK"} default button "OK" with icon note
        end if
        return
    on error
        tell application "System Events"
            activate
            delay 0.1
            if iconName is "stop" then
                display dialog dialogMessage with title dialogTitle buttons {"OK"} default button "OK" with icon stop
            else
                display dialog dialogMessage with title dialogTitle buttons {"OK"} default button "OK" with icon note
            end if
        end tell
    end try
end showDialog

on run argv
    if (count of argv) < 4 then
        error "Usage: gui-script-launcher <success-title> <failure-title> <empty-message> <script-path> [args...]" number 64
    end if

    set successTitle to item 1 of argv
    set failureTitle to item 2 of argv
    set emptyMessage to item 3 of argv
    set targetScript to item 4 of argv
    set extraArguments to {}

    if (count of argv) > 4 then
        repeat with argumentIndex from 5 to count of argv
            set end of extraArguments to item argumentIndex of argv
        end repeat
    end if

    set shellCommand to my buildShellCommand(targetScript, extraArguments)

    try
        set commandOutput to do shell script shellCommand
        my showDialog(successTitle, my successMessage(commandOutput, emptyMessage), "note")
        return "OK"
    on error errMsg number errNum
        my showDialog(failureTitle, my failureMessage(errMsg) & return & return & "Exit code: " & errNum, "stop")
        error errMsg number errNum
    end try
end run
APPLESCRIPT
