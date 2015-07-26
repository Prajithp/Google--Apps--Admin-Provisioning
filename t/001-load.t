#!perl -T

use Test::More tests => 2;

BEGIN {
	use_ok( 'Google::Apps::Admin::Provisioning' );
}

diag( "Testing Google::Apps::Admin::Provisioning $Google::Apps::Admin::Provisioning::VERSION, Perl $], $^X" );

my $google = Google::Apps::Admin::Provisioning->new(
    domain => 'company.com',
    'secret_file' => 't/client_secret.json'
    
);
isa_ok( $google, 'Google::Apps::Admin::Provisioning' );
