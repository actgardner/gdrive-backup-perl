#!/usr/bin/perl 

use strict;
use warnings;

use lib 'lib';

use App::GDriveBackup;

App::GDriveBackup->new_with_command->run;



