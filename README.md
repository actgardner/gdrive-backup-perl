gdrive-perl-backup
===================

Purpose
-------------------
Mostly just to play with the Google Drive API in Perl, because they don't seem to have any docs.

Usage
-------------------
Get a Google Drive API key, you can't have mine! Visit https://code.google.com/apis/console/b/0/ to get set up.

Put your client secret and client name into gdrive_backup.pl.

Generate an OAuth token by running: _perl create\_token.pl_

You'll need to visit the redirect URL in your browser, confirm the app and copy the confirmation string back into the script. The token will be tested out and serialized to a file (oauth.tok by default). Make sure the output file is stored safely, don't put it some place public.

Now you can push files to Google Drive with: _perl gdrive\_backup.pl -d 'Backed Up Doc' -f 'sample_file.txt'_. The best use I can think of is to schedule backups with cron. 

Notes
-------------------
+ I've thrown in a modified version of Net::OAuth. I couldn't get the CPAN version to coerce the hashes Google returned correctly. I may be doing things wrong, let me know.

+ You can replace any existing file by using it's name as the -d flag. If you run the same command multiple times, each upload will be a new version of the last.

+ By default the MIME type is 'text/plain', and we ask Google Docs to convert to their own format. You can change the MIME type by using the -t field. Formats like text, CSV and xls will be viewable in the browser if you set the MIME type properly.

License
-------------------
Can be found in LICENSE, it's just BSD. Go wild.
