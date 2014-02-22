package MT::PluginTheme;
use strict;
use warnings;
use base qw( Class::Accessor::Fast );

my @columns
    = qw( id name author description permalink author_link download_url type );
__PACKAGE__->mk_accessors(@columns);

sub PLUGIN {1}
sub THEME  {2}

sub new { bless {}, shift }

sub datasource {'plugin_theme'}

sub class_label {
    MT->component('InstallPluginsThemes')->translate('Plugin and Theme');
}

sub class_label_plural {
    MT->component('InstallPluginsThemes')->translate('Plugins and Themes');
}
sub container_label        {'Plugin and Theme'}
sub container_label_plural {'Plugins and Themes'}

sub has_column {
    my $col = $_[1];
    return ( grep { $_ eq $col } @columns ) ? 1 : 0;
}

my $items;

sub count {
    my $class = shift;
    my ( $terms, $args ) = @_;

    _get_plugins() or return 0;

    return ref($items) eq 'ARRAY' ? scalar(@$items) : 0;
}

sub load {
    my $class = shift;
    my ( $terms, $args ) = @_;

    _get_plugins() or return;

    my @p;
    my $id = 0;
    for my $data (@$items) {

        my $p = $class->new();

        $p->id( $data->{id} );
        $p->name( $data->{title} );
        $p->author( $data->{author}{displayName} );
        $p->description( $data->{body} );
        $p->permalink( $data->{permalink} );

        my $cf = $data->{customFields};
        if ( ref($cf) eq 'ARRAY' ) {
            my ($author_link)
                = grep { $_->{basename} eq 'pd_author_website_url' } @$cf;
            if ($author_link) {
                $p->author_link( $author_link->{value} );
            }

            my ($download_url)
                = grep { $_->{basename} eq 'pd_download_url' } @$cf;
            if ($download_url) {
                $p->download_url( $download_url->{value} );
            }
        }

        $p->type( $p->download_url =~ m/theme/ ? THEME() : PLUGIN() );

        push @p, $p;
    }

    # Fitler by id.
    if ( exists $terms->{id} ) {
        my @id
            = ref( $terms->{id} ) eq 'ARRAY'
            ? @{ $terms->{id} }
            : ( $terms->{id} );
        my @greped_p;
        for my $p (@p) {
            if ( grep { $p->id eq $_ } @id ) {
                push @greped_p, $p;
            }
        }
        @p = @greped_p;
    }

    # Filter by type.
    if ( ref($terms) eq 'ARRAY' && exists $terms->[0]{type} ) {
        my $type = $terms->[0]{type};
        @p = grep { $_->type == $type } @p;
    }

    my $limit  = $args->{limit}  || 0;
    my $offset = $args->{offset} || 0;
    if ( $limit || $offset ) {
        my $start = $offset < $#p ? $offset : $#p;
        my $end = $limit - 1 + $offset < $#p ? $limit - 1 + $offset : $#p;
        @p = $start == $end ? ( $p[$start] ) : @p[ $start .. $end ];
    }

    return @p;
}

my $ua = MT->new_ua;

sub _get_plugins {

    unless ( defined $items ) {

        # Get JSON of Plugins And Themes Directory
        my $url = MT->component('InstallPluginsThemes')
            ->registry('plugins_themes_directory_url');
        my $res = $ua->get($url);
        return unless $res->is_success;

        # JSON to hash
        my $json = $res->decoded_content;
        require MT::Util;
        my $plugins = MT::Util::from_json($json);
        $items = $plugins->{items};

        my @new_items;
        for my $i (@$items) {
            my $cf = $i->{customFields};
            my ($download_url)
                = grep { $_->{basename} eq 'pd_download_url' } @$cf;

            # Remove plugins and themes installed by the default
            push @new_items, $i unless grep {
                my $match = quotemeta $_;
                $download_url->{value} =~ m/$match/
            } qw( mt-plugin-Loupe mt-theme-rainier mt-theme-eiger );
        }
        $items = \@new_items;
    }

    return $items;
}

sub list_actions {
    return {
        install_plugin_theme => {
            label     => 'Install',
            button    => 1,
            order     => 100,
            mode      => 'install_plugin_theme',
            condition => sub { MT->app->user->is_superuser },
        },
    };
}

sub list_screens {
    return {
        object_label          => 'Plugin and Theme',
        primary               => 'description',
        contents_label        => 'Plugin and Theme',
        contents_label_plural => 'Plugins and Themes',
        view                  => ['system'],
        search_type           => 'plugin_theme',
    };
}

sub list_props {
    return {
        name => {
            label => 'Plugin or Theme Name',
            html  => sub {
                my $permalink = $_[1]->permalink;
                my $name      = $_[1]->name;
                return
                    "<a href=\"${permalink}\" target=\"_blank\"> ${name}</a>";
            },
            display   => 'default',
            order     => 100,
            bulk_sort => sub {
                my $prop = shift;
                my ($objs) = @_;
                return sort { lc( $a->name ) cmp lc( $b->name ) } @$objs;
            },
        },
        author => {
            label => 'Plugin or Theme Author',
            html  => sub {
                if ( $_[1]->author_link ) {
                    my $author_link = $_[1]->author_link;
                    my $author      = $_[1]->author;
                    return
                        "<a href=\"${author_link}\" target=\"_blank\">${author}</a>";
                }
                else {
                    return $_[1]->author;
                }
            },
            display   => 'default',
            order     => 200,
            bulk_sort => sub {
                my $prop = shift;
                my ($objs) = @_;
                return sort { lc( $a->author ) cmp lc( $b->author ) } @$objs;
            },
        },
        type => {
            label => 'Type',
            raw   => sub {
                MT->component('InstallPluginsThemes')
                    ->translate(
                    $_[1]->type == PLUGIN() ? 'Plugin' : 'Theme' );
            },
            order                 => 250,
            base                  => '__virtual.single_select',
            single_select_options => [
                {   label => MT->component('InstallPluginsThemes')
                        ->translate('Plugin'),
                    text  => 'Plugin',
                    value => PLUGIN()
                },
                {   label => MT->component('InstallPluginsThemes')
                        ->translate('Theme'),
                    text  => 'Theme',
                    value => THEME()
                },
            ],
        },
        description => {
            label   => 'Description',
            html    => sub { $_[1]->description },
            display => 'default',
            order   => 300,
        },
    };
}

sub system_filters {
    return {
        plugins_only => {
            label => 'Plugins Only',
            items => [ { type => 'type', args => { value => PLUGIN() } } ],
            order => 100,
        },
        themes_only => {
            label => 'Themes Only',
            items => [ { type => 'type', args => { value => THEME() } } ],
            order => 200,
        },
    };
}

1;
