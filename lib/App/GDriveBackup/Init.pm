package App::GDriveBackup::Init;

use 5.10.0;

use strict;
use warnings;

use MooseX::App::Command;

extends qw/ App::GDriveBackup /;

=head1 NAME

App::GDriveBackup::Init - generate a Google Docs OAauth token.

=head1 SYNOPSIS

create_token.pl [-c <configuration file>]

    You can do some server setup in the config file, by default this is 'gdrive_backup.conf'.

    WARNING: Make sure your token is stored on a path only you can access. Treat it like a private key. 

=cut

use JSON;
use Getopt::Long;
use Pod::Usage;
use Path::Tiny;
use IO::Prompt::Simple;

sub run {
    my $self = shift; 

    #The target file to save the credentials to
    my $token_file = $self->server_config->{token_file};

    my $server = $self->server;

    say "\r\nVisit the following URL in a browser to authorize the app:\r\n\r\n",
        $server->authorize."\r\n";

    chomp( my $auth_code = prompt 'Enter the code generated to continue' );

    say "\r\nExchanging auth token for access token";

    my $access_token = $server->get_access_token($auth_code, grant_type=>'authorization_code');

    say "\r\nTesting access token with Drive query";

    my $resp = $access_token->get("https://www.googleapis.com/drive/v2/files");

    die "The response from the server was bad: \r\n ".$resp->content 
        unless $resp->code == '200';

    path($token_file)->spew($access_token->to_json);

    say "Success! Your OAuth credentials have been stored in $token_file";
}

1;


