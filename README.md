# NAME

Google::Apps::Admin::Provisioning - A Perl library to Google Apps new API system

# SYNOPSIS

```
use Google::Apps::Admin::Provisioning;
use Data::Dumper;

my $client  = GoogleManager->new(
  'secret\_file' => 'path to client\_secret.json', 
  'domain' => 'example.com'
);

my $service = $client->buildService('admin', 'directory\_v1');

print Dumper $client->getLicenseInfo();
```
# DESCRIPTION

Google::Apps::Admin::Provisioning  provides a Perl interface to Google Apps
new API system.

# CONSTRUCTOR

## new ( secret\_file, domain )

Creates a new __Google::Apps::Admin::Provisioning__ object.  
Both domain and secret\_file parameters are required.

# METHODS

## getDefaultLanguage 

Retrieve the domain's default language.

## getorganizationName

Retrieve the domain's organization name. 

## getLicenseInfo

Retrive domain's license informations.

## getAllUsers

Retrieve a list of all users.

The following parameters are optional:

- `customFieldMask customer orderBy query sortOrder viewType`

         https://developers.google.com/admin-sdk/directory/v1/reference/users/list
        

__Example__

my $users = $client->getAllUsers(orderBy => 'email', sortOrder => 'ASCENDING');  

foreach my $pages (@{$users}) {
  foreach my $page (@{$pages}) {
    print $page->{primaryEmail} . "\\n";
  }
}

## getUser

Retrieve a hash containing a user's account information.

__Example__

    my $user = $client->getUser( email => 'prajith.p@example.com' );

## getGroupInfo

Retrieve a group's information.

__Example__
  

    my $group = $client->getGroupInfo( group => 'it@example.com' );
    

## getAllGroups

Retrieve a list of all groups.

__Example__

    $groups = $client->getAllGroups();

## addMembertoGroup
   

Add a member to a group.

The following parameters are required:

- `group`
  

        The value can be the group's email address, group alias, or the unique group ID. 
- `member`
   

        Member email address.
- `role`
  The member's role in a group. Allowed values are:
  

        OWNER	MANAGER MEMBER
        

__Example__

    $result = $client->addMembertoGroup(
      group => 'it@example.com', member => 'prajith@example.com', role => 'MEMBER'
    );
    
