package Plack::App::GzipStatic;
use 5.010;
use strict;
use warnings;

our $VERSION = "0.01";

use parent qw(Plack::App::File);
use constant DEBUG => $ENV{DEBUG_GZIP_STATIC};

#
# Mostly stolen from Plack::App::File, with some tweaks for gzip_static.
#

{
  #
  # Mimic 'use MOP4Import::PSGIEnv qw/psgix.gzip_static/';
  #
  sub Env () {'Plack::App::GzipStatic::Env'}
  package
    Plack::App::GzipStatic::Env; # To hide from indexer.
  use fields qw/HTTP_ACCEPT_ENCODING
                psgi.errors
                psgix.gzip_static/;
}

sub locate_file {
    my ($self, $env) = @_;

    my $path = $env->{PATH_INFO} || '';

    if ($path =~ /\0/) {
        return $self->return_400;
    }

    my $docroot = $self->root || ".";
    my @path = split /[\\\/]/, $path, -1; # -1 *MUST* be here to avoid security issues!
    if (@path) {
        shift @path if $path[0] eq '';
    } else {
        @path = ('.');
    }

    if (grep /^\.{2,}$/, @path) {
        return $self->return_403;
    }

    my ($file, @path_info);
    while (@path) {
        my $try = File::Spec::Unix->catfile($docroot, @path);

        # =============
        # HERE is 1st tweak for gzip_static
        # =============
        if ($file = $self->should_handle($try, $env)) {
            last;
        } elsif (!$self->allow_path_info) {
            last;
        }
        unshift @path_info, pop @path;
    }

    if (!$file) {
        return $self->return_404;
    }

    if (!-r $file) {
        return $self->return_403;
    }

    return $file, join("/", "", @path_info);
}

sub serve_path {
    my ($self, $env, $file) = @_;

    # ================
    # HERE is 2nd tweak for gzip_static
    # ================
    my @enc;
    my $content_type = do {
      if (my $ext = $env->{'psgix.gzip_static'}) {
        push @enc, 'Content-Encoding', 'gzip';
        Plack::MIME->mime_type($ext)
      } else {
        Plack::MIME->mime_type($file)
      }
    } || 'text/plain';

    if ($content_type =~ m!^text/!) {
        $content_type .= "; charset=" . ($self->encoding || "utf-8");
    }

    open my $fh, "<:raw", $file
        or return $self->return_403;

    my @stat = stat $file;

    Plack::Util::set_io_path($fh, Cwd::realpath($file));

    return [
        200,
        [
            'Content-Type'   => $content_type,
            'Content-Length' => $stat[7],
            'Last-Modified'  => HTTP::Date::time2str( $stat[9] ),
            @enc
        ],
        $fh,
    ];
}

#========================================

sub dputs {
  (my Env $env, my $msg) = @_;
  $env->{'psgi.errors'}->print("# gzip_static: ", $msg, "\n");
}

#
# This *UPDATES* $path argument to real path.
#
sub should_handle {
  (my $self, my $path, my Env $env) = @_;

  my $can_use_gzip
    = ($env->{HTTP_ACCEPT_ENCODING} // '') =~ /\bgzip\b/;

  my ($ext) = $path =~ /(\.[^\.]+)$/;

  if ($can_use_gzip and -r (my $gz = "$path.gz")) {
    unless (defined $ext and $ext ne '') {
      dputs($env, "No extension in $gz for $path") if DEBUG;
      return undef;
    }
    $env->{'psgix.gzip_static'} = $ext;
    dputs($env, "use $gz for $path") if DEBUG;
    return $gz;

  } elsif (-r $path) {
    dputs($env, $can_use_gzip
          ? "no gzip, fallback to $path"
          : "no accept-encoding gzip for $path") if DEBUG;
    return $path;

  } elsif (defined $ext and -r (my $real = "$path$ext")) {
    # Apache MultiViews support. ( .js => .js.js )
    dputs($env, "fallback to $real") if DEBUG;
    return $real;

  } else {
    dputs($env, "Not found for $path") if DEBUG;
    return undef;
  }
}

# gzip(can)     gz(has) path(has)       ext(has)        => use gzip
# gzip(can)     gz(has) path(has)       ext(no_)        => use gzip
# gzip(can)     gz(has) path(no)        ext(has)        => use gzip
# gzip(can)     gz(has) path(no)        ext(no_)        => use gzip
# gzip(can)     gz(no)  path(has)       ext(has)        => use path w/o gzip
# gzip(can)     gz(no)  path(has)       ext(no_)        => use path w/o gzip
# gzip(can)     gz(no)  path(no)        ext(has)        => use ext w/o gzip
# gzip(can)     gz(no)  path(no)        ext(no_)        => 404 not found
# gzip(not)     gz(has) path(has)       ext(has)        => use path w/o gzip
# gzip(not)     gz(has) path(has)       ext(no_)        => use path w/o gzip
# gzip(not)     gz(has) path(no)        ext(has)        => use ext w/o gzip
# gzip(not)     gz(has) path(no)        ext(no_)        => 404 not found
# gzip(not)     gz(no)  path(has)       ext(has)        => use path w/o gzip
# gzip(not)     gz(no)  path(has)       ext(no_)        => use path w/o gzip
# gzip(not)     gz(no)  path(no)        ext(has)        => use ext w/o gzip
# gzip(not)     gz(no)  path(no)        ext(no_)        => 404 not found

1;
__END__

=encoding utf-8

=head1 NAME

Plack::App::GzipStatic - mimics gzip_static

=head1 SYNOPSIS

    use Plack::App::GzipStatic;
    my $app = Plack::App::GzipStatic->new({root => "/path/to/static"})->to_app;

    # When PATH_INFO is "/bootstrap.css",
    # returns 'bootstrap.css.gz'   if it exists and HTTP_ACCEPT_ENCODING has gzip.
    # returns 'bootstrap.css'      if it exists.
    # returns 'bootstrap.css.css'  if it exists. (For Apache MultiViews)
    # 404                          otherwise.

    builder {
       mount "/static" => $app;

       mount "/" => sub {
          ... # main app
       };
    };

=head1 DESCRIPTION

This is a static file server (most codes are stolen from L<Plack::App::File>)
with additional feature B<gzip_static>,
known for L<nginx|https://nginx.org/en/docs/http/ngx_http_gzip_static_module.html> and L<Apache|https://feeding.cloud.geek.nz/posts/serving-pre-compressed-files-using/>.

=head2 How it works

Assume we use Plack::App::GzipStatic like following.

    use Plack::App::GzipStatic;
    my $app = Plack::App::GzipStatic->new({root => $root})->to_app;

When this $app called with C<< $env->{PATH_INFO} = "/bootstrap.css" >>,
this module behaves like followings (in this order):

=over 4

=item Try F<$root/bootstrap.css.gz> when C<< $env->{HTTP_ACCEPT_ENCODING} >> has F<gzip>

If it exists, returns this file with C<Content-Encoding: gzip>.

=item Try F<$root/bootstrap.css>

If it exists, returns this file as usual.

=item Try F<$root/bootstrap.css.css>

If it exists, returns this file as usual. This helps co-operating with Apache MultiViews.

=item Otherwise

returns 404.

=back


=head1 LICENSE

Copyright (C) Kobayasi, Hiroaki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Kobayasi, Hiroaki E<lt>buribullet@gmail.comE<gt>

=cut

