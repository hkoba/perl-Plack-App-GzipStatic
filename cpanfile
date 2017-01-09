requires 'perl', '5.010001';

requires 'fields';
requires 'File::Spec';

requires 'Plack::App::File';
requires 'Plack::Util';
requires 'Plack::MIME';
requires 'HTTP::Date';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Kantan';
    requires 'Plack::Test';
    requires 'HTTP::Request::Common';
};

