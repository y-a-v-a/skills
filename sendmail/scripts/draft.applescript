-- draft.applescript — open a new Outlook draft for review. Never sends.
--
-- Usage: osascript draft.applescript <subject.txt> <body.html> <recipients.tsv>
--
-- Values arrive as UTF-8 files, not as string literals or shell arguments, so
-- nothing needs AppleScript or shell escaping:
--   subject.txt     one line; anything after the first line is ignored
--   body.html       the HTML body
--   recipients.tsv  one recipient per line: <display name><TAB><address>
--                   (display name may be empty; the address is then used)

on run argv
	if (count of argv) is not 3 then error "usage: osascript draft.applescript subject.txt body.html recipients.tsv"
	set theSubject to paragraph 1 of my readUTF8(item 1 of argv)
	set theBody to my readUTF8(item 2 of argv)
	set theRecipients to my parseRecipients(my readUTF8(item 3 of argv))
	if (count of theRecipients) is 0 then error "no recipients in " & (item 3 of argv)

	tell application "Microsoft Outlook"
		set msg to make new outgoing message with properties {subject:theSubject, content:theBody}
		tell msg
			repeat with r in theRecipients
				make new recipient at end of to recipients ¬
					with properties {email address:{name:(item 1 of r), address:(item 2 of r)}}
			end repeat
		end tell
		open msg
		activate
	end tell
	return "draft opened: " & (count of theRecipients) & " recipient(s)"
end run

on readUTF8(p)
	return read (POSIX file p) as «class utf8»
end readUTF8

-- Returns a list of {name, address}; blank lines are skipped.
on parseRecipients(txt)
	set out to {}
	set savedTID to AppleScript's text item delimiters
	set AppleScript's text item delimiters to tab
	repeat with ln in paragraphs of txt
		set ln to ln as text
		if ln is not "" then
			set parts to text items of ln
			if (count of parts) ≥ 2 then
				set theName to item 1 of parts
				set theAddress to item 2 of parts
			else
				set theName to ""
				set theAddress to item 1 of parts
			end if
			if theName is "" then set theName to theAddress
			set end of out to {theName, theAddress}
		end if
	end repeat
	set AppleScript's text item delimiters to savedTID
	return out
end parseRecipients
