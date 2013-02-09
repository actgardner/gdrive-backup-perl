#!/usr/bin/env perl

=head1 NAME

create_token.pl - Command line tool to generate a Google Docs OAauth token.

=head1 USAGE

create_token.pl [-c <configuration file>]

    You can do some server setup in the config file, by default this is 'gdrive_backup.conf'.

    WARNING: Make sure your token is stored on a path only you can access. Treat it like a private key. 

=cut

use strict;
use warnings;

use Net::OAuth2::Profile::WebServer;
use JSON;
use File::Slurp;
use Getopt::Long;
use Pod::Usage;

#Load the JSON config
my $server_config_file = "gdrive_backup.conf";
my $conf_content;
my $server_config;

GetOptions( 
    "config|c=s" => \$server_config_file,
    "help|h!"    => \my $help,
    'man!'       => \my $man,
) or pod2usage( -verbose => 0 );

pod2usage( -verbose => 1 ) if $help;
pod2usage( -verbose => 2 ) if $man;

eval { $conf_content = File::Slurp::read_file($server_config_file) };
die "Couldn't open server config file $server_config_file\r\n$@\r\n" if ($@);

eval { $server_config = decode_json($conf_content) }; die "Invalid JSON in server config $server_config_file\r\n$@\r\n" if ($@);

#The target file to save the credentials to
my $token_file = $server_config->{'token_file'};

my $server = Net::OAuth2::Profile::WebServer->new(
               %{$server_config->{'oauth_conf'}},
               access_type=>'offline');

print "\r\nVisit the following URL in a browser to authorize the app:\r\n\r\n";
print $server->authorize."\r\n";
print "\r\nEnter the code generated to continue: ";

my $auth_code = <STDIN>;

chomp( $auth_code );

print "\r\nExchanging auth token for access token\r\n";

my $access_token = $server->get_access_token($auth_code, grant_type=>'authorization_code');

print "\r\nTesting access token with Drive query\r\n";

my $resp = $access_token->get("https://www.googleapis.com/drive/v2/files");

die "The response from the server was bad: \r\n ".$resp->content 
    unless $resp->code == '200';

eval {File::Slurp::write_file($token_file, $access_token->to_json()) };
die "Couldn't store credentials in file $token_file\r\n$@\r\n" if ($@);

print "Success! Your OAuth credentials have been stored in $token_file\r\n";
