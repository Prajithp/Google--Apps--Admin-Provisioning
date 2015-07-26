use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Google::Apps::Admin::Provisioning',
    ABSTRACT            => 'A Perl library to Google\'s RESTful Apps API',
    AUTHOR              => 'Prajith P <prajith@ndiemsnionz.com>',
    VERSION_FROM        => 'lib/Google/Apps/Admin/Provisioning.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Carp'              		=> 0,
        'Google::API::Client'    	=> 0,
        'Google::API::OAuth2::Client'	=> 0,
        'HTTP::Request'			=> 0,
        'JSON'				=> 0,
        'Furl'				=> 0,
        'Test::More'        		=> 0,
        'XML::Simple'       		=> 0
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Google/Apps/Admin/Provisioning-*' },
);

