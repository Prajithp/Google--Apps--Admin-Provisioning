package Google::Apps::Admin::Provisioning;

use strict;
use Google::API::Client			();
use Google::API::OAuth2::Client		();
use HTTP::Request			();
use Furl                                ();
use XML::Simple				();
use JSON				();
use Data::Dumper			();
use Carp                		();

our $VERSION = '1.1.1';

=head1 NAME

Google::Apps::Admin::Provisioning - A Perl library to Google Apps new API system

=head1 SYNOPSIS

use Google::Apps::Admin::Provisioning;
use Data::Dumper;

my $client  = GoogleManager->new(
  'secret_file' => 'path to client_secret.json', 
  'domain' => 'example.com'
);
my $service = $client->buildService('admin', 'directory_v1');

print Dumper $client->getLicenseInfo();

=head1 DESCRIPTION

Google::Apps::Admin::Provisioning  provides a Perl interface to Google Apps
new API system.

=head1 CONSTRUCTOR

=head2 new ( secret_file, domain )

Creates a new B<Google::Apps::Admin::Provisioning> object.  
Both domain and secret_file parameters are required.

=head1 METHODS

=head2 getDefaultLanguage 

Retrieve the domain's default language.

=head2 getorganizationName

Retrieve the domain's organization name. 

=head2 getLicenseInfo

Retrive domain's license informations.

=head2 getAllUsers

Retrieve a list of all users.

The following parameters are optional:

=over 4

=item C<customFieldMask customer orderBy query sortOrder viewType>

  https://developers.google.com/admin-sdk/directory/v1/reference/users/list
 
=back

B<Example>

my $users = $client->getAllUsers(orderBy => 'email', sortOrder => 'ASCENDING');  

foreach my $pages (@{$users}) {
  foreach my $page (@{$pages}) {
    print $page->{primaryEmail} . "\n";
  }
}

=head2 getUser

Retrieve a hash containing a user's account information.

B<Example>

  my $user = $client->getUser( email => 'prajith.p@example.com' );

=head2 getGroupInfo

Retrieve a group's information.

B<Example>
  
  my $group = $client->getGroupInfo( group => 'it@example.com' );
  
=head2 getAllGroups

Retrieve a list of all groups.

B<Example>

  $groups = $client->getAllGroups();

=head2 addMembertoGroup
   
Add a member to a group.

The following parameters are required:

=over 4

=item C<group>
  
  The value can be the group's email address, group alias, or the unique group ID. 

=item C<member>
   
   Member email address.

=item C<role>
  The member's role in a group. Allowed values are:
  
  OWNER	MANAGER MEMBER
  
=back

B<Example>

  $result = $client->addMembertoGroup(
    group => 'it@example.com', member => 'prajith@example.com', role => 'MEMBER'
  );
  
=cut 

# Google Api doc urls which I used to write this module.

# https://developers.google.com/admin-sdk/directory/v1/guides/manage-users
# https://developers.google.com/admin-sdk/admin-settings/

use constant 'admin_settings_url' => 'https://apps-apis.google.com/a/feeds/domain/2.0/';

sub new {
  my ($class, %args) = @_;
  
  my $self = { %args };
  
  
  unless ($self->{domain} and -f $self->{secret_file}) {
    die "Google App Domain and Secret file required";
  }
  
  $self->{ua} ||= Furl->new(
      agent => __PACKAGE__,
  );

  $self->{google_client} = Google::API::Client->new;
  $self->{json_parser}   = JSON->new();
  $self->{xml_parser}    = XML::Simple->new();
  $self->{auth_file}     ||= $ENV{HOME} . "/.google_auth.json";

  return bless($self, $class);;
}

sub ua {
  my ($self, $ua) = @_;
  return $self->{ua} unless $ua;
  
  $self->{ua} = $ua;
}

sub buildService {
  my ($self, $service, $version) = @_;
  
  my $file = $self->{secret_file};
  
  $self->{service}     = $self->{google_client}->build($service, $version);
  
  $self->{service}->{auth_doc}->{oauth2}->{scopes}->{'https://www.googleapis.com/auth/apps.groups.settings'} = { 
    'description' => 'Manage your group settings' 
  };
  $self->{service}->{auth_doc}->{oauth2}->{scopes}->{'https://apps-apis.google.com/a/feeds/domain/'} = { 
    'description' => 'Manage your domain settings' 
  };

  $self->{auth_driver} = Google::API::OAuth2::Client->new_from_client_secrets($file, $self->{service}->{auth_doc});
  $self->get_access_token;

  return $self->{service};
}

sub getAuthDriver {
  my $self = shift;
  
  return $self->{auth_driver};
}

sub store_token {
  my $self = shift;
  
  my $access_token = $self->{auth_driver}->token_obj;
  open (my $fh, '>', $self->{auth_file});
  if ($fh) {
    print $fh $self->{json_parser}->encode($access_token);
    close $fh;
  }
}

sub get_access_token {
  my $self = shift;
  
  my $access_token;
  if (-f $self->{auth_file}) {
    open my $fh, '<', $self->{auth_file};
    if ($fh) {
      local $/;
      $access_token = $self->{json_parser}->decode(<$fh>);
      close $fh;
    }
    $self->{auth_driver}->token_obj($access_token);
  }
  else {
    my $auth_url = $self->{auth_driver}->authorize_uri;
    print "Go to the following link in your browser:\n";
    print "$auth_url\n";
    
    print 'Enter verification code:';
    my $code = <STDIN>;
    chomp $code;
    $access_token = $self->{auth_driver}->exchange($code);
    $self->store_token;
  }
}

sub ApiRequest {
  my $self  = shift;

  my $arg;
  %{$arg} = @_;
  map { $arg->{$_} = $arg->{$_} } keys %{$arg};

  my $url     = $arg->{url};
  my $method  = uc($arg->{method}) || 'GET';

  my $request = HTTP::Request->new($method => $url);
  
  if ($arg->{content}) {
    $request->content_type('application/json');
    $request->header('Content-Length' => length($arg->{'body'}));
    $request->content($self->{json_parser}->encode($arg->{content}));
  }
  
  $request->header('Authorization', sprintf "%s %s",
      $self->{auth_driver}->token_type,
      $self->{auth_driver}->access_token
  );

  my $response = $self->ua->request($request);
  if ($response->code == 401 && $self->{auth_driver}) {
    $self->{auth_driver}->refresh;
    $request->header('Authorization', sprintf "%s %s",
        $self->{auth_driver}->token_type,
        $self->{auth_driver}->access_token
    );
    $response = $self->ua->request($request);
  }

  unless ($response->is_success) {
    my  $errors = eval { $self->{json_parser}->decode($response->content) };
    if ($errors->{error}) {
        return $errors->{error};
    }
    else {
      Carp::croak $response->status_line;
    }
  }
  if ($response->code == 204) {
    return 1;
  }

  if ($response->header('content-type') =~ m!^application/json!) {
    return ($self->{json_parser}->decode($response->content));
  }
  elsif ($response->header('content-type') =~ m!^application/atom\+xml!) {
    return($self->{xml_parser}->XMLin($response->content()));
  }
  else {
    return $response->content;
  }
}

sub getDefaultLanguage {
  my $self = shift;
  
  my $url      = admin_settings_url . "$self->{domain}/general/defaultLanguage";
  my $response = $self->ApiRequest(url => $url, method => 'GET');
  
  return $response->{'apps:property'};
}

sub getorganizationName {
  my $self = shift;
  
  my $url      = admin_settings_url . "$self->{domain}/general/organizationName";
  my $response = $self->ApiRequest(url => $url, method => 'GET');
  
  return $response->{'apps:property'};
}

sub getLicenseInfo {
  my $self = shift;
  
  my $max_users_url      = admin_settings_url . "$self->{domain}/general/maximumNumberOfUsers";
  my $max_users_response = $self->ApiRequest(url => $max_users_url, method => 'GET');
  my $max_users          = $max_users_response->{'apps:property'}->{value};

  my $cur_users_url      = admin_settings_url . "$self->{domain}/general/currentNumberOfUsers";
  my $cur_users_response = $self->ApiRequest(url => $cur_users_url, method => 'GET');
  my $cur_users          = $cur_users_response->{'apps:property'}->{value};

  my $data = {
    'free'        => $max_users - $cur_users,
    'maxAccount'  => $max_users,
    'curAccount'  => $cur_users, 
  };

  return $data;
}

sub getAllUsers {
  my $self = shift;

  my $args;
  %{$args} = @_;
  map { $args->{$_} = $args->{$_} } keys %{$args};

  my $url = "https://www.googleapis.com/admin/directory/v1/users?domain=$self->{domain}&maxResults=500";

  for my $arg (qw/customFieldMask customer orderBy query sortOrder viewType/) {
    $url .= "&$arg=$args->{$arg}" if $args->{$arg};
  }
  
  my @result;
  while(1) {
     my $api_respones  = $self->ApiRequest(url => $url, method => 'GET');
     push(@result, $api_respones->{users});
     my $page_token    = $api_respones->{nextPageToken} if $api_respones->{nextPageToken};
     last unless($page_token);
     $url .= "&pageToken=$page_token";
  }  
  return \@result;
}

sub getUser {
  my $self  = shift;
  
  my $args;
  %{$args} = @_;
  map { $args->{$_} = $args->{$_} } keys %{$args};

  Carp::croak "user email account is required" unless $args->{email};
 
  my $url   = "https://www.googleapis.com/admin/directory/v1/users/$args->{email}";
  my $api_respones = $self->ApiRequest(url => $url, method => 'GET');
 
  return $api_respones;
}

sub getGroupInfo {
  my $self  = shift;
  
  my $args;
  %{$args} = @_;
  map { $args->{$_} = $args->{$_} } keys %{$args};

  Carp::croak "group name is required" unless $args->{group};

  my $url   = "https://www.googleapis.com/admin/directory/v1/groups/$args->{group}";
  my $api_respones  = $self->ApiRequest(url => $url, method => 'GET');

  return $api_respones;
}

sub getAllGroups {
  my $self = shift;
  
  my $url = "https://www.googleapis.com/admin/directory/v1/groups?domain=$self->{domain}&maxResults=500";
  
  my @result;
  # Only 500 results can be retrived per request, thats why I wrote infinit while loop
  while(1) {
     my $api_respones  = $self->ApiRequest(url => $url, method => 'GET');
     push(@result, $api_respones->{groups});
     my $page_token    = $api_respones->{nextPageToken} if $api_respones->{nextPageToken};
     last unless($page_token);
     $url .= "&pageToken=$page_token";
  }
  return @result;
}


sub addMembertoGroup {
  my $self = shift;

  my $args;
  %{$args} = @_;
  map { $args->{$_} = $args->{$_} } keys %{$args};

  for my $param (qw/role group member/) {
     Carp::croak "param $param is required" unless $args->{$param};
  }

  my $url = "https://www.googleapis.com/admin/directory/v1/groups/$args->{group}/members";
  my $api_respones  = $self->ApiRequest(url => $url, method => 'POST', content => {role => $args->{role}, email => $args->{member}});

  return $api_respones;

}

sub getMemberGroups {
   my $self = shift;

  my $args;
  %{$args} = @_;
  map { $args->{$_} = $args->{$_} } keys %{$args};

  Carp::croak "Member email id is required" unless $args->{member};

  my $url = "https://www.googleapis.com/admin/directory/v1/groups?userKey=$args->{member}&maxResults=200&domain=$self->{domain}";

  my @result;
  while(1) {
     my $api_respones  = $self->ApiRequest(url => $url, method => 'GET');
     push(@result, $api_respones->{members});
     my $page_token    = $api_respones->{nextPageToken} if $api_respones->{nextPageToken};
     last unless($page_token);
     $url .= "&pageToken=$page_token";
  }
  return @result;
}

sub getGroupMember {
  my ($self, $group, $member)  = @_;
  
  Carp::croak "group email id and member id is required" unless($group || $member);

  my $url = "https://www.googleapis.com/admin/directory/v1/groups/$group/members/$member";

  my $api_respones  = $self->ApiRequest(url => $url, method => 'GET');
  return $api_respones;   
}

sub getGroupMembers {
  my $self = shift;
  
  my $args;
  %{$args} = @_;
  map { $args->{$_} = $args->{$_} } keys %{$args};

  Carp::croak "Group key is required" unless($args->{group});
  my $url = "https://www.googleapis.com/admin/directory/v1/groups/$args->{group}/members?maxResults=200";
  
  my @result;
  while(1) {
     my $api_respones  = $self->ApiRequest(url => $url, method => 'GET');
     push(@result, $api_respones->{members});
     my $page_token    = $api_respones->{nextPageToken} if $api_respones->{nextPageToken};
     last unless($page_token);
     $url .= "&pageToken=$page_token";
  }
  return @result;
}

sub deleteGroupMembership {
  my $self = shift;
  my ($group, $member) = @_;

  Carp::croak "Group key and Member id is required" unless ($group || $member);

  my $url = "https://www.googleapis.com/admin/directory/v1/groups/$group/members/$member";
  my $api_respones  = $self->ApiRequest(url => $url, method => 'DELETE');  

  return $api_respones;
}

sub updateGroupMembership {
  my $self = shift;

  my $args;
  %{$args} = @_;
  map { $args->{$_} = $args->{$_} } keys %{$args};

  for my $param (qw/role group member/) {
     Carp::croak "param $param is required" unless $args->{$param};
  }
  
  my $url = "https://www.googleapis.com/admin/directory/v1/groups/$args->{group}/members/$args->{member}";
  my $api_respones  = $self->ApiRequest(url => $url, method => 'PUT', content => { role => $args->{role}});

  return $api_respones;
}


sub _validateEmail {
  my $string = @_;

  return $string;
}

1;
  
