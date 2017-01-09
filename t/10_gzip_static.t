#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";

use Plack::App::GzipStatic;

use Test::Kantan;
use Plack::Test;
use HTTP::Request::Common;

describe "Basics", sub {

  describe "When you have foo.css.gz and foo.css", sub {
    my $app = Plack::App::GzipStatic->new(root => my $root = "$Bin/has_gz");

    test_psgi $app, sub {
      my $cb = shift;

      describe "And when ACCEPT_ENCODING contains gzip", sub {
        my $res = $cb->(GET "/foo.css", 'Accept-Encoding' => 'gzip');

        my $want_real = "$root/foo.css.gz";

        describe "response for /foo.css", sub {
          it "should return statically gzipped content", sub {
            expect($res->code)->to_be(200);
            expect($res->content_type)->to_be('text/css');
            expect($res->header('Content-Encoding'))->to_be('gzip');
            expect($res->content_length)->to_be(-s $want_real);
          };
        };
      };

      describe "When ACCEPT_ENCODING exists but doesn't contain gzip", sub {
        my $res = $cb->(GET "/foo.css", 'Accept-Encoding' => 'deflate');

        my $want_real = "$root/foo.css";

        describe "response for /foo.css", sub {
          it "should fallback to uncompressed content", sub {
            expect($res->code)->to_be(200);
            expect($res->content_type)->to_be('text/css');
            expect(not exists $res->headers->{'Content-Encoding'})->to_be_true;
            expect($res->content_length)->to_be(-s $want_real);
          };
        };
      };

      describe "When ACCEPT_ENCODING is missing", sub {
        my $res = $cb->(GET "/foo.css");

        my $want_real = "$root/foo.css";

        describe "response for /foo.css", sub {
          it "should fallback to uncompressed content", sub {
            expect($res->code)->to_be(200);
            expect($res->content_type)->to_be('text/css');
            expect(not exists $res->headers->{'Content-Encoding'})->to_be_true;
            expect($res->content_length)->to_be(-s $want_real);
          };
        };
      };
    };
  };

  describe "When you have foo.css.gz and foo.css.css", sub {
    my $app = Plack::App::GzipStatic->new(root => my $root = "$Bin/css_css");

    test_psgi $app, sub {
      my $cb = shift;

      describe "And when ACCEPT_ENCODING contains gzip", sub {
        my $res = $cb->(GET "/foo.css", 'Accept-Encoding' => 'gzip');

        my $want_real = "$root/foo.css.gz";

        describe "response for /foo.css", sub {
          it "should return statically gzipped content", sub {
            expect($res->code)->to_be(200);
            expect($res->content_type)->to_be('text/css');
            expect($res->header('Content-Encoding'))->to_be('gzip');
            expect($res->content_length)->to_be(-s $want_real);
          };
        };
      };

      describe "When ACCEPT_ENCODING is missing", sub {
        my $res = $cb->(GET "/foo.css");

        my $want_real = "$root/foo.css.css";

        describe "response for /foo.css", sub {
          it "should fallback to uncompressed content", sub {
            expect($res->code)->to_be(200);
            expect($res->content_type)->to_be('text/css');
            expect(not exists $res->headers->{'Content-Encoding'})->to_be_true;
            expect($res->content_length)->to_be(-s $want_real);
          };
        };
      };
    };
  };

  describe "When you have foo.css only", sub {
    my $app = Plack::App::GzipStatic->new(root => my $root = "$Bin/no_gz");
    my $want_real = "$root/foo.css";

    test_psgi $app, sub {
      my $cb = shift;

      describe "And when ACCEPT_ENCODING contains gzip", sub {
        my $res = $cb->(GET "/foo.css", 'Accept-Encoding' => 'gzip');

        describe "response for /foo.css", sub {
          it "should fallback to uncompressed content", sub {
            expect($res->code)->to_be(200);
            expect($res->content_type)->to_be('text/css');
            expect(not exists $res->headers->{'Content-Encoding'})->to_be_true;
            expect($res->content_length)->to_be(-s $want_real);
          };
        };
      };

      describe "When ACCEPT_ENCODING is missing", sub {
        my $res = $cb->(GET "/foo.css");

        describe "response for /foo.css", sub {
          it "should fallback to uncompressed content", sub {
            expect($res->code)->to_be(200);
            expect($res->content_type)->to_be('text/css');
            expect(not exists $res->headers->{'Content-Encoding'})->to_be_true;
            expect($res->content_length)->to_be(-s $want_real);
          };
        };
      };
    };
  };
};

done_testing();
