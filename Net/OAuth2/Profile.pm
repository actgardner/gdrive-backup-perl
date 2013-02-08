# Copyrights 2013 by [Mark Overmeer].
#  For other contributors see Changes.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 2.01.
package Net::OAuth2::Profile;
use vars '$VERSION';
$VERSION = '0.52';

use warnings;
use strict;

use LWP::UserAgent ();
use URI            ();
use JSON           qw/decode_json/;
use Carp           qw/confess carp/;
use Scalar::Util   qw/blessed/;
use Encode         qw/encode/;
use Data::Dumper;

use constant MIME_URLENC => 'application/x-www-form-urlencoded';

# old names still supported:
#   bearer_token_scheme => token_scheme

sub new(@)
{   my $class = shift;
    $class ne __PACKAGE__
        or carp 'you need to create an extension, not base-class '.__PACKAGE__;
    (bless {}, $class)->init( {@_} );
}

# rfc6849 Appendix B, http://www.w3.org/TR/1999/REC-html401-19991224
sub _url_enc($)
{   my $x = encode 'utf8', shift;  # make bytes
    $x =~ s/([^A-Za-z0-9 ])/sprintf("%%%02x", ord $1)/ge;
    $x =~ s/ /+/g;
    $x; 
}

sub init($)
{   my ($self, $args) = @_;
    my $id     = $self->{NOP_id}     = $args->{client_id}
        or carp "profile needs id";
    my $secret = $self->{NOP_secret} = $args->{client_secret}
        or carp "profile needs secret";

    $self->{NOP_id_enc}     = _url_enc $id;
    $self->{NOP_secret_enc} = _url_enc $secret;

    $self->{NOP_agent}  = $args->{user_agent} || LWP::UserAgent->new;
    $self->{NOP_scheme} = $args->{token_scheme}
        || $args->{bearer_token_scheme} || 'auth-header:OAuth';
    $self->{NOP_scope}  = $args->{scope};
    $self->{NOP_method} = $args->{access_token_method} || 'POST';
    $self->{NOP_acc_param}   = $args->{access_token_param} || [];
    $self->{NOP_init_params} = $args->{init_params};
    $self->{NOP_grant_type}  = $args->{grant_type};

    my $site = $self->{NOP_site}  = $args->{site};
    foreach my $c (qw/access_token protected_resource authorize refresh_token/)
    {   my $link = $args->{$c.'_url'} || $args->{$c.'_path'} || "/oauth/$c";
        $self->{"NOP_${c}_url"}    = $self->site_url($link);
        $self->{"NOP_${c}_method"} = $args->{$c.'_method'} || 'POST';
        $self->{"NOP_${c}_param"}  = $args->{$c.'_param'}  || [];
    }

    $self;
}

#----------------

sub id()         {shift->{NOP_id}}
sub id_enc()     {shift->{NOP_id_enc}}
sub secret()     {shift->{NOP_secret}}
sub secret_enc() {shift->{NOP_secret_enc}}
sub user_agent() {shift->{NOP_agent}}
sub site()       {shift->{NOP_site}}
sub scope()      {shift->{NOP_scope}}
sub grant_type() {shift->{NOP_grant_type}}

sub bearer_token_scheme() {shift->{NOP_scheme}}

#----------------

sub request($@)
{   my ($self, $request) = (shift, shift);
#print $request->as_string;
    my $response = $self->user_agent->request($request, @_);
#print $response->as_string;
#$response;
}


sub request_auth(@)
{   my ($self, $token) = (shift, shift);
    my $request;
    if(@_==1) { $request = shift }
    else
    {   my ($method, $uri, $header, $content) = @_;
        $request = HTTP::Request->new
          ( $method => $self->site_url($uri)
          , $header, $content
          );
    }
    $self->add_token($request, $token, $self->bearer_token_scheme);
    print Dumper($request);
    $self->request($request);
}

#--------------------

sub site_url($@)
{   my ($self, $path) = (shift, shift);
    my @params = @_==1 && ref $_[0] eq 'HASH' ? %{$_[0]} : @_;
    my $site = $self->site;
    my $url  = $site ? URI->new_abs($path, $site) : URI->new($path);
    $url->query_form($url->query_form, @params) if @params;
    $url;
}


sub add_token($$$)
{   my ($self, $request, $token, $bearer) = @_;
    my $access  = $token->access_token;

    my ($scheme, $opt) = split ':', $bearer;
    $scheme = lc $scheme;
    if($scheme eq 'auth-header')
    {   # Specs suggest using Bearer or OAuth2 for this value, but OAuth
        # appears to be the de facto accepted value.
        # Going to use OAuth until there is wide acceptance of something else.
        my $auth_scheme = $opt || 'OAuth';
        $request->headers->header(Authorization => "$auth_scheme $access");
    }
    elsif($scheme eq 'uri-query')
    {   my $query_param = $opt || 'oauth_token';
        $request->uri->query_form($request->uri->query_form
          , $query_param => $access);
    }
    elsif($scheme eq 'form-body')
    {   $request->headers->content_type eq MIME_URLENC
            or die "embedding access token in request body is only valid "
                 . "for 'MIME_URLENC' content type";

        my $query_param = $opt || 'oauth_token';
        my $content     = $request->content;
        $request->add_content(($content && length $content ?  '&' : '')
           . uri_escape($query_param).'='.uri_escape($access));
    }
    else
    {   carp "unknown bearer schema $bearer";
    }

    $request;
}


sub build_request($$$)
{   my ($self, $method, $uri_base, $params) = @_;
    $params = [ %$params ] if ref $params eq 'HASH';

    my $request;

    if($method eq 'POST')
    {   my $p = URI->new('http:');   # taken from HTTP::Request::Common
        $p->query_form(@$params);

        $request = HTTP::Request->new
          ( $method => $uri_base
          , [Content_Type => MIME_URLENC]
          , $p->query
          );
    }
    elsif($method eq 'GET')
    {   my $uri = blessed $uri_base && $uri_base->isa('URI')
          ? $uri_base->clone : URI->new($uri_base);

        $uri->query_form($uri->query_form, @$params);
        $request = HTTP::Request->new($method, $uri);
    }
    else
    {   confess "unknown request method $method";
    }

    my $uri  = $request->uri;
    my $head = $request->headers;
    $request->protocol('HTTP/1.1');
    $head->header(Host => $uri->host_port);
    $head->header(Connection => 'Keep-Alive');
    $request;
}


sub params_from_response($$)
{   my ($self, $response, $why) = @_;
    my ($error, $content);
    $content = $response->decoded_content || $response->content if $response;
    if(!$response)
    {   $error = 'no response received';
    }
    elsif(!$response->is_success)
    {   $error = 'received error: '.$response->status_line;
    }
    else
    {   # application/json is often not correctly configured: is not
        # (yet) an apache pre-configured extension   :(
        if(my $params = eval {decode_json $content} )
        {   # content is JSON
            #return ref $params eq 'HASH' ? %$params : @$params;
            return $params;
        }

        # otherwise form-encoded parameters (I hope)
        my $uri     = URI->new;
        $uri->query($content);
        my @res_params = $uri->query_form;
        return @res_params if @res_params;

        $error = "cannot read parameters from response";
    }
    
    substr($content, 200) = '...' if length $content > 200;
    die "failed oauth call $why: $error\n$content\n";
}

sub authorize_method()          {panic}  # user must use autorize url
sub access_token_method()       {shift->{NOP_access_token_method} }
sub refresh_token_method()      {shift->{NOP_refresh_token_method} }
sub protected_resource_method() {shift->{NOP_protected_resource_method} }

sub authorize_url()             {shift->{NOP_authorize_url}}
sub access_token_url()          {shift->{NOP_access_token_url}}
sub refresh_token_url()         {shift->{NOP_refresh_token_url}}
sub protected_resource_url()    {shift->{NOP_protected_resource_url}}

sub authorize_params(%)
{   my $self   = shift;
    my %params = (@{$self->{NOP_authorize_param}}, @_);
    $params{scope}         ||= $self->scope;
    $params{client_id}     ||= $self->id;
    \%params;
}

sub access_token_params(%)
{   my $self   = shift;
    my %params = (@{$self->{NOP_access_token_param}}, @_);
    $params{code}          ||= '';
    $params{client_id}     ||= $self->id;
    $params{client_secret} ||= $self->secret;
    $params{grant_type}    ||= $self->grant_type;
    \%params;
}

sub refresh_token_params(%)
{   my $self   = shift;
    my %params = (@{$self->{NOP_refresh_token_param}}, @_);
    $params{client_id}     ||= $self->id;
    $params{client_secret} ||= $self->secret;
    \%params;
}

sub protected_resource_params(%)
{   my $self   = shift;
    my %params = (@{$self->{NOP_protected_resource_param}}, @_);
    \%params;
}

1;
