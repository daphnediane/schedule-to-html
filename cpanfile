# cpanfile for desc_tbl
requires 'perl', '>= 5.036';
requires 'common::sense';
requires 'Date::Parse';
requires 'File::Slurp';
requires 'HTML::Tiny';
requires 'List::MoreUtils';
requires 'Object::InsideOut';
requires 'Readonly';
requires 'Readonly::XS';
requires 'Spreadsheet::ParseXLSX';

on 'develop' => sub {
    # should this be recommends
    requires 'Devel::NYTProf';
    requires 'Perl::Critic';
    requires 'Perl::Critic::TooMuchCode';
    requires 'Perl::LanguageServer';
    requires 'Perl::Tidy';
};