<!--
The pre-workshop email (#14, #19), sent with the Setup release on 9 Nov evening.
Don't send this file: send the output of `./build.sh email`, which fills in
{{BUNDLE_DATE}} and {{DRIVE_LINK}} and pulls steps 3-5 and the Mac block from
the setup card (cards/setup.md), so that text is written once.
Never add the repo URL here (#15).
-->
Subject: DuckDB Workshop Series 2 (11–13 Nov): please set up your laptop by Tuesday 10 Nov, 12.00

Dear Participant,

Before the workshop, please set up the laptop you'll bring and reply to this email by **Tuesday 10 Nov, 12.00**. Nothing needs installing and you need no admin rights.

1. Use the laptop you'll bring to the workshop, with at least 10 GB free.
2. Open this MyGovUC Drive link, signed in with your MyGovUC account, and download `duckdb-bundle-{{BUNDLE_DATE}}.zip`: {{DRIVE_LINK}}
<!-- include cards/setup.md#at-home -->
6. Reply to this email with the block at the end, filled in.

On a Mac, steps 3 and 4 are different:

<!-- include cards/setup.md#mac -->

The reply block (keep one answer per line):

```
Laptop: Windows x64 / Windows ARM / Mac Apple Silicon / Mac Intel / government-managed
Banner: <paste the SETUP line>
First cell: rows / <exact error text, or a screenshot>
MyGovUC Drive link opened: yes / no
DuckDB/SQL experience: none / some / use it regularly
```

If the banner says `SETUP FAILED`, reply anyway: I'll answer every `FAILED` reply on the afternoon of 10 Nov with the fix for your laptop.

If your laptop is still not working, you couldn't reply, or the Drive link didn't open, please arrive at **8.30** on Day 1 (Wednesday 11 Nov), and I'll fix your laptop first. Bring only the laptop and its charger.

Bring a phone with mobile data that can share a hotspot, in case the venue network blocks the DuckDB UI.

All the hospital data in the workshop is synthetic, not real hospital performance.

Later updates go into the `updates` folder.

See you on Wednesday,
Workshop facilitator, DuckDB Workshop Series 2
