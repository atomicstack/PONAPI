# ABSTRACT: request - retrieve
package PONAPI::Client::Request::Retrieve;

use Moose;

with 'PONAPI::Client::Request',
     'PONAPI::Client::Request::Role::IsGET',
     'PONAPI::Client::Request::Role::HasType',
     'PONAPI::Client::Request::Role::HasId',
     'PONAPI::Client::Request::Role::HasFields',
     'PONAPI::Client::Request::Role::HasFilter',
     'PONAPI::Client::Request::Role::HasInclude',
     'PONAPI::Client::Request::Role::HasPage',
     'PONAPI::Client::Request::Role::HasUriSingle';

__PACKAGE__->meta->make_immutable;
no Moose; 1;

__END__
