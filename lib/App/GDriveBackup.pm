package App::GDriveBackup;

use strict;
use warnings;

use MooseX::App;

use YAML::Any qw/ LoadFile /;
use Net::OAuth2::Profile::WebServer;

option 'config' => (
    isa => 'Str',
    is => 'ro',
    default => 'gdrive_backup.conf',
);

has server_config => (
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    default => sub {
        LoadFile( $_[0]->config );
    },
);

has server => (
    is => 'ro',
    lazy => 1,
    default => sub {
        Net::OAuth2::Profile::WebServer->new(
            %{$_[0]->server_config->{oauth_conf}},
            access_type=>'offline'
        );
    },
);

1;
