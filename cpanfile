# cpanfile for desc_tbl
requires 'perl', '>= 5.038';
requires 'common::sense';
requires 'Date::Parse';
requires 'Feature::Compat::Class';
requires 'File::Slurp';
requires 'HTML::Tiny';
requires 'List::MoreUtils';
requires 'Object::InsideOut';
requires 'Readonly';
requires 'Spreadsheet::ParseXLSX';
requires 'Sub::Name';

on 'develop' => sub {

    # should this be recommends
    requires 'Devel::NYTProf';
    requires 'Perl::Critic';
    requires 'Perl::Critic::TooMuchCode';
    requires 'Perl::LanguageServer';
    requires 'Perl::Tidy';
};