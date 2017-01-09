# NAME

Plack::App::GzipStatic - mimics gzip\_static

# SYNOPSIS

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

# DESCRIPTION

This is a static file server (most codes are stolen from [Plack::App::File](https://metacpan.org/pod/Plack::App::File))
with additional feature **gzip\_static**,
known for [nginx](https://nginx.org/en/docs/http/ngx_http_gzip_static_module.html) and [Apache](https://feeding.cloud.geek.nz/posts/serving-pre-compressed-files-using/).

## How it works

Assume we use Plack::App::GzipStatic like following.

    use Plack::App::GzipStatic;
    my $app = Plack::App::GzipStatic->new({root => $root})->to_app;

When this $app called with `$env->{PATH_INFO} = "/bootstrap.css"`,
this module behaves like followings (in this order):

- Try `$root/bootstrap.css.gz` when `$env->{HTTP_ACCEPT_ENCODING}` has `gzip`

    If it exists, returns this file with `Content-Encoding: gzip`.

- Try `$root/bootstrap.css`

    If it exists, returns this file as usual.

- Try `$root/bootstrap.css.css`

    If it exists, returns this file as usual. This helps co-operating with Apache MultiViews.

- Otherwise

    returns 404.

# LICENSE

Copyright (C) Kobayasi, Hiroaki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Kobayasi, Hiroaki <buribullet@gmail.com>
