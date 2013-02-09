#!/usr/bin/env perl

=head1 NAME

create_token.pl - Command line tool to generate a Google Docs OAauth token.

=head1 USAGE

create_token.pl [-c <configuration file>]

    You can do some server setup in the config file, by default this is 'gdrive_backup.conf'.

    WARNING: Make sure your token is stored on a path only you can access. Treat it like a private key. 

=cut

use 5.10.0;

use strict;
use warnings;

use Net::OAuth2::Profile::WebServer;
use JSON;
use Getopt::Long;
use Pod::Usage;
use Path::Tiny;
use IO::Prompt::Simple;

#Load the JSON config
my $server_config_file = "gdrive_backup.conf";

GetOptions( 
    "config|c=s" => \$server_config_file,
    "help|h!"    => \my $help,
    'man!'       => \my $man,
) or pod2usage( -verbose => 0 );

pod2usage( -verbose => 1 ) if $help;
pod2usage( -verbose => 2 ) if $man;

my $server_config = decode_json( path($server_config_file)->slurp );

#The target file to save the credentials to
my $token_file = $server_config->{'token_file'};

my $server = Net::OAuth2::Profile::WebServer->new(
               %{$server_config->{'oauth_conf'}},
               access_type=>'offline');

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
