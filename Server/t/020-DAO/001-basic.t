#!perl

use strict;
use warnings;

use Scalar::Util qw[ blessed ];

use Test::More;

BEGIN {
    use_ok('PONAPI::DAO');
    use_ok('Test::PONAPI::DAO::Repository::MockDB');
    use_ok('Test::PONAPI::DAO::Repository::MockDB::Loader');
}

my $repository = Test::PONAPI::DAO::Repository::MockDB->new;
isa_ok($repository, 'Test::PONAPI::DAO::Repository::MockDB');

ok($repository->has_type('people'),   '... we have the people type');
ok($repository->has_type('articles'), '... we have the articles type');
ok($repository->has_type('comments'), '... we have the comments type');

ok(!$repository->has_type('widgets'), '... we do not have the widgets type');

ok($repository->has_relationship(articles => 'authors'),   '... we have the expected (articles => author) relationship');
ok($repository->has_relationship(articles => 'comments'),  '... we have the expected (articles => comments) relationship');
ok($repository->has_relationship(comments => 'articles'),  '... we have the expected (comments => article) relationship');
ok($repository->has_relationship(people   => 'articles'),  '... we have the (people => articles) relationship');

ok(!$repository->has_relationship(comments => 'authors'),  '... we do not have the (comments => author) relationship (as expected)');

my $dao = PONAPI::DAO->new( repository => $repository );
isa_ok($dao, 'PONAPI::DAO');

subtest '... retrieve all' => sub {
    my $doc = $dao->retrieve_all( type => 'people', req_base => '/', send_doc_self_link => 1 );

    ok(!blessed($doc), '... the document we got is not blessed');
    is(ref $doc, 'HASH', '... the document we got is a HASH ref');

    ok(exists $doc->{'jsonapi'}, '... we have a `jsonapi` key');
    ok(exists $doc->{'data'}, '... we have a `data` key');
    ok(exists $doc->{'links'}, '... we have a `links` key');
    is(scalar keys %$doc, 3, '... only got 3 keys');

    is(ref $doc->{'data'}, 'ARRAY', '.... the document->{data} we got is an ARRAY ref');

    foreach my $person ( @{$doc->{'data'}} ) {
        is(ref $person, 'HASH', '... the resource we got is a HASH ref');
        is($person->{type}, 'people', '... got the expected type');

        ok(exists $person->{id}, '... the `id` key exists');
        ok(exists $person->{attributes}, '... the `attributes` key exists');

        ok(exists $person->{attributes}->{name}, '... the attribute `name` key exists');
        ok(exists $person->{attributes}->{age}, '... the attribute `age` key exists');
        ok(exists $person->{attributes}->{gender}, '... the attribute `gender` key exists');
    }
};

subtest '... retrieve' => sub {
    my $doc = $dao->retrieve(
        type     => 'articles',
        id       => 2,
        fields   => { articles => [qw< title >] },
        req_base => '/',
    );

    ok(!blessed($doc), '... the document we got is not blessed');
    is(ref $doc, 'HASH', '... the document we got is a HASH ref');

    my $data = $doc->{data};
    ok($data, '... the document has a `data` key');
    ok(ref $data eq 'HASH', '... the document has one resource');

    ok(scalar keys %{ $data->{attributes} } == 1, '... one key in `attributes`');
    ok(exists $data->{attributes}->{title}, '... the attribute `title` key exists');

};

subtest '... retrieve relationships' => sub {
    my $doc = $dao->retrieve_relationships(
        type     => 'articles',
        id       => 2,
        rel_type => 'comments',
        req_base => '/',
    );

    ok(!blessed($doc), '... the document we got is not blessed');
    is(ref $doc, 'HASH', '... the document we got is a HASH ref');

    my $data = $doc->{data};
    ok(ref $data eq 'ARRAY', '... the document has multiple resources');
    ok(scalar @{$data} == 2, '... the document has 2 resources');
    ok(ref $data->[0] eq 'HASH', '... the 1st resouce is a HASH ref');
    ok(exists $data->[0]->{type}, '... the 1st resouce has a `type` key');
    ok(exists $data->[0]->{id}, '... the 1st resouce has an `id` key');
    is(keys( %{ $data->[0] } ), 2, "... that those are the only keys it returns")
};

subtest '... retrieve by relationship' => sub {
    my $doc = $dao->retrieve_by_relationship(
        type     => 'articles',
        id       => 2,
        rel_type => 'authors',
        req_base => '/',
    );

    ok(!blessed($doc), '... the document we got is not blessed');
    is(ref $doc, 'HASH', '... the document we got is a HASH ref');

    my $data = $doc->{data};
    ok(ref $data eq 'HASH', '... the document has one resource');
    ok(exists $data->{attributes}->{age}, '... the attribute `age` key exists');
    ok(exists $data->{attributes}->{gender}, '... the attribute `gender` key exists');
    ok(exists $data->{attributes}->{name}, '... the attribute `name` key exists');
    # Note that we requested the 'authors' relationship type, which is a collection
    # of people, so type for whatever was retrieved has to be 'person'
    is($data->{type}, 'people', '... retrieved document is of the correct type');

    $doc = $dao->retrieve_by_relationship(
        type     => 'articles',
        id       => 2,
        rel_type => 'comments',
    );

    ok(!blessed($doc), '... the document we got is not blessed');
    is(ref $doc, 'HASH', '... the document we got is a HASH ref');

    $data = $doc->{data};
    ok(ref $data eq 'ARRAY', '... the document has multiple resources');
    is(scalar(@$data), 2, "... two resources, in fact");
};

subtest '... update' => sub {
    my %who    = (type => 'articles', id => 2);
    my $orig   = $dao->retrieve( %who );
    my $backup = $dao->retrieve( %who );

    my $new_title = "Yadda yadda";
    my @update_ret = $dao->update(
        %who,
        data => {
            %who,
            attributes => {
                title  => $new_title,
            }
        },
    );
    is($update_ret[0], 202, "... default successful update returns a 202");
    my $doc = $update_ret[2];
    ok( exists $doc->{meta} && !exists $doc->{data}, "... which has a meta but no body" );

    my $new = $dao->retrieve( %who );

    ok(!blessed($doc), '... the document we got is not blessed');
    is(ref $doc, 'HASH', '... the document we got is a HASH ref');

    ok($doc->{meta}, "... (optional) meta member is present");

    $orig->{data}{attributes}{title} = $new_title;
    delete $_->{data}{attributes}{updated} for $orig, $new;
    is_deeply($orig, $new, "... update works");

    $dao->update(
        %who,
        data => {
            %who,
            relationships => {
                authors => { type => "people", id => 777 },
            }
        }
    );

    $orig->{data}{relationships}{authors}{data}{id} = 777;
    my $updated = $dao->retrieve( %who );

    delete $updated->{data}{attributes}{updated};
    is_deeply($updated, $orig, "... can update one-to-one relationships");

    my $new_comments = [
        {type => comments => id => 55},
        {type => comments => id => 56},
    ];
    $dao->update(
        %who,
        data => {
            %who,
            relationships => {
                comments => $new_comments,
            },
        }
    );
    $updated = $dao->retrieve( %who );

    delete $updated->{data}{attributes}{updated};
    $orig->{data}{relationships}{comments}{data} = $new_comments;
    is_deeply($updated, $orig, "... and many-to-many");

    my @res = $dao->update( %who, data => { %who, relationships => { authors => undef, comments => [] } } );
    $updated = $dao->retrieve( %who );

    delete $orig->{data}{relationships};
    delete $updated->{data}{attributes}{updated};
    is_deeply($updated, $orig, "... can clear relationships via update");

    use Storable qw/dclone/;
    my $data_for_restore = dclone( $backup->{data} );
    $data_for_restore->{relationships}{$_} = delete $data_for_restore->{relationships}{$_}{data}
        for keys %{ $data_for_restore->{relationships} };
    $dao->update( %who, data => $data_for_restore );
    $updated = $dao->retrieve(%who);

    my $backup_updated = delete $backup->{data}{attributes}{updated};
    delete $updated->{data}{attributes}{updated};
    is_deeply($updated, $backup, "... successfully 'restored' the comment");

    my $new_dao    = PONAPI::DAO->new( repository => $repository, respond_to_updates_with_200 => 1 );
    my @update_200 = $new_dao->update( type => comments => id => 12, data => { type => comments => id => 12, attributes => { body => "This changes nothing extra" } } );
    is($update_200[0], 200, "... can set the DAO to return 200 on updates");
    ok( exists $doc->{meta} && !exists $doc->{data}, "... which has a meta and no data, because it has no side effects");

    @update_200 = $new_dao->update( %who, data => { %who, attributes => { title => "This changes updated" } } );
    my $new_updated = delete $update_200[2]->{data}{attributes}{updated};
    isnt($new_updated, $backup_updated, "... the updated date auto-changed,");
    is_deeply(
        \@update_200,
        [ 200, [], {
      'data' => {
         'type' => 'articles',
         'attributes' => {
           'created' => '2015-06-22 14:56:29',
           'body' => 'The 2nd shortest article. Ever.',
           'title' => 'This changes updated',
           'status' => 'ok'
         },
         'links' => { self => '/articles/2' },
         'id' => 2,
         'relationships' => {
             'comments' => {
               'data' => [
                   { 'id' => 5, 'type' => 'comments' },
                   { 'type' => 'comments', 'id' => 12 }
               ],
               links => {
                related => '/articles/2/comments',
                self    => '/articles/2/relationships/comments'
               },
             },
             'authors' => {
                'data' => { 'type' => 'people', 'id' => 88 },
                'links' => {
                    'related' => '/articles/2/authors',
                    'self'    => '/articles/2/relationships/authors'
                },
              }
           }
       },
      'jsonapi' => { 'version' => '1.0' },
      'meta'    => {
        message => q!successfully updated the resource /articles/2 => {"relationships":null,"type":"articles","id":"2","attributes":{"title":"This changes updated"}}!,
      }
      }],
        "...so now it returns a full resource object + meta"
    );
};

subtest '... delete_relationships' => sub {
    my @res = $dao->delete_relationships(
        type     => "articles",
        id       => 2,
        rel_type => "comments",
        data     => [
            { type => comments => id => 5 },
        ],
    );
    is_deeply(
        \@res,
         [
            200,
            [],
            {
              jsonapi => { version => '1.0' },
              meta    => { message => 'successfully deleted the relationship /articles/2/comments => [{"id":5}]' }
            }
         ],
         "... can delete as expected",
    );

    my @retrieve = $dao->retrieve(
        type     => "articles",
        id       => 2,
    );

    delete $retrieve[2]->{data}{attributes}{updated};
    my $expect = [
            200,
            [],
            {
              data    => {
                           attributes
                                   => {
                                        body    => 'The 2nd shortest article. Ever.',
                                        created => '2015-06-22 14:56:29',
                                        status  => 'ok',
                                        title   => 'This changes updated',
                                      },
                           links   => { self => '/articles/2' },
                           id      => 2,
                           relationships
                                   => {
                                        authors  => { data => {
                                                      id   => 88,
                                                      type => 'people'
                                                    },
                                                    links => {
                                                      related => '/articles/2/authors',
                                                      self    => '/articles/2/relationships/authors'
                                                    }
                                        },
                                        comments => { data => [
                                                      {
                                                        id   => 12,
                                                        type => 'comments'
                                                      }
                                                    ],
                                                      links => {
                                                                 related => '/articles/2/comments',
                                                                 self    => '/articles/2/relationships/comments'
                                                               }                                                     }
                                      },
                           type    => 'articles'
                         },
              jsonapi => { version => '1.0' }
            }
          ];
    is_deeply(\@retrieve, $expect, "... and the correct changes are retrieved");
    
    # Multiple deletes, what does meta say?
    # TODO with 200s + extra changes, need to do the retrieve dance
};

subtest '... create + create_relationship' => sub {
    my ($status_author, $headers_author, $doc_for_author_create) = $dao->create(
        type => 'people',
        data => {
            type => 'people',
            attributes => {
                name => 'Doof',
                age  => 33,
                gender => 'female',
            },
        },
    );
    is( $status_author, 201, "... correct status for create" );
    # Brittle...
    is_deeply(
        $headers_author,
        [ Location => '/people/92' ],
        "... has the Location header for the create"
    );
    ok(!exists $doc_for_author_create->{errors}, "... no errors, created the new person");
    unlike($doc_for_author_create->{data}{id}, qr/\A(?:0|42|88|91|)\z/, "... and got a new id for them");

    my $author_id = $doc_for_author_create->{data}{id};

    my ($status_article, $headers_article, $article_doc) = $dao->create(
        type => 'articles',
        data => {
            type => 'articles',
            attributes => {
                title => "Brand new test article!",
                body  => "With a brand new body!",
            },
            relationships => {
                authors => { type => 'people', id => $author_id }
            },
        }
    );

    is( $status_article, 201, "... correct status for article create" );
    is_deeply( $headers_article, [ Location => '/articles/4' ], "... has the Location header" );

    my ($status_comment, $headers_comment, $comment_doc) = $dao->create(
        type => 'comments',
        data => {
            type => 'comments',
            attributes => {
                body => "Great insight",
            },
        },
    );

    is( $status_comment, 201, "... correct status for comment create" );
    my $comment_id = $comment_doc->{data}{id};

    my $article_id = $article_doc->{data}{id};
    my @create_rel = $dao->create_relationships(
        type     => "articles",
        id       => $article_id,
        rel_type => "comments",
        data => [
            { type => comments => id => $comment_id },
        ],
    );

    my $retrieved = $dao->retrieve(
        type    => "articles",
        id      => $article_id,
        include => [qw/ authors comments /],
    );
    delete @{ $retrieved->{data}{attributes} }{qw/ created status updated /};
    @{ $retrieved->{included} } =  sort { $a->{type} cmp $b->{type} } @{ $retrieved->{included} };

    my $expect = {
           data     => {
               attributes
                       => {
                            body  => 'With a brand new body!',
                            title => 'Brand new test article!'
                          },
               id      => 4,
               links   => { self => "/articles/$article_id" },
               relationships
                       => {
                            authors  => {
                                          data  => {
                                                     id   => $author_id,
                                                     type => 'people'
                                                   },
                                          links => {
                                                     related => "/articles/$article_id/authors",
                                                     self    => "/articles/$article_id/relationships/authors"
                                                   }
                                        },
                            comments => {
                                          data  => [{
                                                     id   => 13,
                                                     type => 'comments'
                                                   }],
                                          links => {
                                                     related => "/articles/$article_id/comments",
                                                     self    => "/articles/$article_id/relationships/comments"
                                                   }
                                        }
                          },
               type    => 'articles'
           },
           included => [
                         {
                           attributes
                                 => { body => 'Great insight' },
                           id    => 13,
                           type  => 'comments'
                         },
                         {
                           attributes
                                 => {
                                      age    => 33,
                                      gender => 'female',
                                      name   => 'Doof'
                                    },
                           id    => 92,
                           type  => 'people'
                         }
                       ],
           jsonapi  => { version => '1.0' }
         };


    is_deeply($retrieved, $expect, "... retrieve with include returns all we have done");

    my @update_rel = $dao->update_relationships(
        type => "articles",
        id   => $article_id,
        rel_type => "comments",
        data => [],
    );
    is_deeply( \@update_rel, [
            200,
            [],
            {
              jsonapi => { version => '1.0' },
              meta    => { message => "successfully updated the relationship /articles/$article_id/comments => []" }
            }
          ], "... update_relationships cleared comments" );

    my @delete = $dao->delete( type => "people", id => $author_id );
    is_deeply( \@delete,
        [
            200,
            [],
            {
              jsonapi => { version => '1.0' },
              meta    => { message => "successfully deleted the resource /people/$author_id" }
            }
        ], "... delete cleared the author" );

    my $retrieved_again = $dao->retrieve(
        type    => "articles",
        id      => $article_id,
        include => [qw/ authors comments /], 
    );
    delete @{ $retrieved_again->{data}{attributes} }{qw/ created status updated /}; 

    my $final_expect = {
        'jsonapi' => { 'version' => '1.0' },
        'data'    => {
            'type'       => 'articles',
            'attributes' => {
                'body'  => 'With a brand new body!',
                'title' => 'Brand new test article!'
            },
            links   => { self => "/articles/$article_id" },
            'relationships' => {
                'authors' => {
                    'data' => {
                        'type' => 'people',
                        'id'   => $author_id,
                    },
                    links => {
                        related => "/articles/$article_id/authors",
                        self    => "/articles/$article_id/relationships/authors",
                    },
                }
            },
            'id' => $article_id,
        }
    };
    is_deeply($retrieved_again, $final_expect, "... including missing resources works");
    
    # Special case; updating a one-to-one lets you pass undef.
    # See http://jsonapi.org/format/#crud-updating-to-one-relationships
    TODO: {
        local $TODO = "TBI";
        my @author_update_rel = eval {$dao->update_relationships(
            type => "articles",
            id   => $article_id,
            rel_type => "author",
            data => undef,
        )};
    }
};

# TODO
#
# No Content

done_testing;