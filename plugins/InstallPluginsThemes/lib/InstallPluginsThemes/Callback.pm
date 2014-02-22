package InstallPluginsThemes::Callback;
use strict;
use warnings;

# Change 'Find Themes' link.
sub tmpl_src_list_theme {
    my ( $cb, $app, $tmpl_ref ) = @_;
    _replace_anchor_tag(
        {   app        => $app,
            tmpl_ref   => $tmpl_ref,
            pre_url    => '<__trans phrase="_THEME_DIRECTORY_URL">',
            filter_key => 'themes_only',
        }
    );
}

# Change 'Find Plugins' link.
sub tmpl_src_cfg_plugin {
    my ( $cb, $app, $tmpl_ref ) = @_;
    _replace_anchor_tag(
        {   app        => $app,
            tmpl_ref   => $tmpl_ref,
            pre_url    => '<__trans phrase="_PLUGIN_DIRECTORY_URL">',
            filter_key => 'plugins_only',
        }
    );
}

sub _replace_anchor_tag {
    my $args = shift;

    my $app        = $args->{app};
    my $tmpl_ref   = $args->{tmpl_ref};
    my $pre_url    = $args->{pre_url};
    my $filter_key = $args->{filter_key};

    # Replace URL.
    $pre_url = quotemeta $pre_url;
    my $post_url = $app->uri(
        mode => 'list',
        args => {
            _type      => 'plugin_theme',
            blog_id    => 0,
            filter_key => $filter_key,
        },
    );
    $$tmpl_ref =~ s/$pre_url/$post_url/;

    # Remove target attribute in anchor tag.
    my $remove = quotemeta ' target="_blank"';
    $$tmpl_ref =~ s/$remove//;
}

# Hide MT::PluginTheme when upgrading.
sub upgrade_init_app {
    require MT::Upgrade;
    my $init = \&MT::Upgrade::init;
    no warnings 'redefine';
    *MT::Upgrade::init = sub {
        $init->(@_);
        delete $MT::Upgrade::classes{plugin_theme};
    };
}

1;
