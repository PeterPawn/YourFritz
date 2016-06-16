## custom configuration framework
The scripts in this subdirectory build a solution (based solely on a full-featured BusyBox binary, xz_comp is an optional
component and may be used to get a better compression rate for the settings archive file) to manage additional settings
for extension packages in a single archive file, which is unpacked each time the device will be started and where any 
changes to the settings directory are monitored by inotifyd. If a monitored file has been changed, a countdown will be 
started. If the timeout elapses, the changes recorded so far will be written to a new archive, which will be used for
unpacking on the next start.

This "lazy writing" ensures that no package needs to maintain its own precautions to save changes (like Freetz framework
does with the mod_save script), because they will get noticed and saved automatically. On the other hand it prevents the
system from writing the changed settings archive multiple times, if more than one file is changed (it's not unusual, that
a configuration action needs to change multiple files) within a short period.

The script files contain comments to explain the intention of some actions ... please read them carefully.
