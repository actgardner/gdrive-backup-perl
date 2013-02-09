package App::GDriveBackup::Backup;

use 5.10.0;

use strict;
use warnings;

use MooseX::App::Command;

extends qw/ App::GDriveBackup /;

=head1 NAME

App::GDriveBackup::Backup - upload document to Google Docs using serialized OAuth token.

=head1 SYNOPSIS

    gdrive_backup -d <doc name to save to> -s <source file to backup> [-c <configuration file>] [ -f <MIME type> ] [-h]

Requires a source file (to upload), and a filename to use on Google Docs. If a doc with this name exists, it will be replaced.

You have to authorize the app as well, with create_token.pl. 

=cut

use Data::Dumper;
use JSON;
use Getopt::Long;
use Path::Tiny;

option source_file => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    documentation => 'source document',
);

option target_doc => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    documentation => 'target document',
);

option file_type => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    documentation => 'file type',
);

has access_token => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $self = shift;

        my $access_token = $self->server->create_access_token(
            decode_json( path($self->server_config->{token_file})->slurp )
        );

        $self->server->update_access_token($access_token);

        return $access_token;
    }
);

sub run {
    my $self = shift;

    my $document_id = $self->get_document_id;

    $self->upload_document( $document_id );
}

sub upload_document {
    my( $self, $document_id ) = @_;

    my $resp = $self->access_token->put(
        "https://www.googleapis.com/upload/drive/v2/files/$document_id?uploadType=media&convert=true",
        ['Content-Type'=>$self->file_type],
        path($self->source_file)->slurp
    );

    die "Failed to upload, HTTP error ".$resp->code unless $resp->code == 200;

    say $self->source_file, " uploaded as ", $self->target_doc;
}

sub get_document_id {
    my $self = shift;

    my $resp = $self->access_token->get(
        sprintf "https://www.googleapis.com/drive/v2/files?q=title='%s'",
                $self->target_doc
    );

    die 'Got HTTP error listing documents', $resp->code unless $resp->code == 200;

    my $existing_docs = decode_json($resp->content);

    return $existing_docs->{'items'}[0]{id} if @{$existing_docs->{items}};

    $resp = $self->access_token->post("https://www.googleapis.com/drive/v2/files/",
        ['Content-Type'=>'application/json'],
        encode_json({'title'=> $self->target_doc})
    );

    die "Failed to create file, HTTP error ".$resp->code unless $resp->code == 200;

    return decode_json($resp->content)->{id};
}

1;
