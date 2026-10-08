# Phone check

Everything marked "never run on a phone" in docs/DECISIONS.md is listed in the app under
**Settings > Diagnostics and phone check**: tick each item "Works" or "Broken", add notes
(which AI, what happened), tap **Copy report** and send it. The report holds the build number,
phone OS, counts, recent backup results, the tick-list and the local error log (crashes and
unexpected errors, kept on the phone only).

Order that finds the most problems fastest:
1. Install over the old version (no uninstall) and open the app.
2. Review a few cards; Learn something new; copy and share the prompt.
3. Paste an answer from each AI you use; then share an answer into the app.
4. Choose a backup folder; Back up now; look for the `.db.gz` file; Restore latest.
5. Edit and delete a card; Memory model (note how long a fit takes).
6. Turn on the daily reminder two minutes ahead.
7. Dark mode and the largest text size.

The build number in the report matches the title of the release the APK came from. If it is
older than the newest build, download again before testing.
