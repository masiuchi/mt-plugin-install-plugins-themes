package InstallPluginsThemes::Callback;
use strict;
use warnings;

sub init_app {
    require MT::CMS::Search;
    my $core_search_apis = \&MT::CMS::Search::core_search_apis;
    no warnings 'redefine';
    *MT::CMS::Search::core_search_apis = sub {
        my $types = $core_search_apis->(@_);
        $types->{plugin_theme} = {
            label     => 'Plugins or Themes',
            condition => sub {0},
        };
        return $types;
    };
}

sub tmpl_src_list_theme {
    my ( $cb, $app, $tmpl_ref ) = @_;

    my $pre  = quotemeta '<__trans phrase="_THEME_DIRECTORY_URL">';
    my $post = $app->uri(
        mode => 'list',
        args => { _type => 'plugin_theme', blog_id => 0 }
    );
    $$tmpl_ref =~ s/$pre/$post/;

    my $remove = quotemeta ' target="_blank"';
    $$tmpl_ref =~ s/$remove//;
}

sub tmpl_src_cfg_plugin {
    my ( $cb, $app, $tmpl_ref ) = @_;

    my $pre  = quotemeta '<__trans phrase="_PLUGIN_DIRECTORY_URL">';
    my $post = $app->uri(
        mode => 'list',
        args => { _type => 'plugin_theme', blog_id => 0 }
    );
    $$tmpl_ref =~ s/$pre/$post/;

    my $remove = quotemeta ' target="_blank"';
    $$tmpl_ref =~ s/$remove//;
}

1;
