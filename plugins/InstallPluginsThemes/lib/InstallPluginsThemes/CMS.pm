package InstallPluginsThemes::CMS;
use strict;
use warnings;

use File::Copy::Recursive qw/ dircopy /;
use File::Spec;
use File::Temp qw/ tempdir /;

use MT::Util::Archive::Zip;

sub install_plugin_theme {
    my $app = shift;

    # Check
    return $app->errtrans('Invalid request.')
        unless $app->request_method eq 'POST' && $app->validate_magic;
    return $app->permission_denied unless $app->user->is_superuser;

    # Set IDs
    $app->setup_filtered_ids
        if $app->param('all_selected');
    my @id = $app->param('id');

    # Get plugin data
    require MT::PluginTheme;
    my @plugin = MT::PluginTheme->load( { id => \@id } );

    # Unzip and copy
    for my $p (@plugin) {

        # Create temporary directory.
        my $download_dir = tempdir(
            DIR => $app->config->TempDir,
            $MT::DebugMode ? () : ( CLEANUP => 1 )
        );

        # Generate download URL of zip file.
        my $download_url = _get_url_to_zip( $p->download_url );
        next unless $download_url;
        MT->log( 'Donwload URL: ' . $download_url ) if $MT::DebugMode;
        my ($zip_file) = ( $download_url =~ m/\/([^\/]+)$/ );
        my $download_path = File::Spec->catfile( $download_dir, $zip_file );

        # Download zip file.
        my $ua
            = $app->new_ua( { max_size => $app->config->MaxDownloadSize } );
        my $res
            = $ua->get( $download_url, ':content_file' => $download_path );
        next unless $res->is_success;

        # Unzip zip file.
        my $arc = MT::Util::Archive::Zip->new( 'zip', $download_path );
        next unless $arc;
        $arc->extract($download_dir) or next;

        if ( my $plugin_root = _search_plugin_root($download_dir) ) {

            # Plugin
            my $no_plugins_dir;
            if ( ref $plugin_root ) {
                $no_plugins_dir = $plugin_root->{no_plugins_dir};
                $plugin_root    = $plugin_root->{plugin_root};
            }
            next unless $plugin_root;

            _copy_files(
                {   from           => $plugin_root,
                    to             => $MT::MT_DIR,
                    no_plugins_dir => $no_plugins_dir
                }
            );
        }
        elsif ( my $theme_root = _search_theme_root($download_dir) ) {

            # Theme
            my $no_themes_dir;
            if ( ref $theme_root ) {
                $no_themes_dir = $theme_root->{no_themes_dir};
                $theme_root    = $theme_root->{theme_root};
            }
            next unless $theme_root;

            _copy_files(
                {   from          => $theme_root,
                    to            => $MT::MT_DIR,
                    no_themes_dir => $no_themes_dir
                }
            );
        }
    }

    return $app->redirect(
        $app->uri(
            mode => 'list',
            args => {
                _type     => 'plugin_theme',
                blog_id   => 0,
                installed => 1,
            },
        )
    );
}

# Get URL to zip file.
sub _get_url_to_zip {
    my $url = shift;

    # SKYARC
    if ( $url =~ m/\.html$/ ) {
        my $ua
            = MT->new_ua( { max_size => MT->app->config->MaxDownloadSize } );
        my $res = $ua->get($url);
        return unless $res->is_success;
        my $content = $res->decoded_content;
        return unless $content;
        my @zip_url = ( $content =~ m/<a\s*[^<>]*\s*href="([^"]+\.zip)"/g );
        $url = @zip_url ? pop @zip_url : undef;
        return $url;
    }

    # GitHub
    unless ( $url =~ m/\.zip$/ ) {
        unless ( $url =~ m/\/$/ ) {
            $url .= '/';
        }
        $url .= 'archive/master.zip';
    }

    return $url;
}

# Search plugin root directory.
sub _search_plugin_root {
    my $dir = shift;
    return unless $dir;
    _search_recursive(
        $dir,
        {   dir          => 'plugins',
            check_no_dir => sub {
                return
                    grep { $_ =~ m/\.pl$/ || $_ =~ m/config\.yaml$/ }
                    @{ (shift) };
            },
            no_dir => sub {
                return +{ plugin_root => shift, no_plugin_dir => 1 };
            },
        },
    );
}

# Search theme root directory.
sub _search_theme_root {
    my $dir = shift;
    return unless $dir;
    _search_recursive(
        $dir,
        {   dir          => 'themes',
            check_no_dir => sub {
                return grep { $_ =~ m/theme\.yaml$/ } @{ (shift) };
            },
            no_dir => sub {
                return +{ theme_root => shift, no_theme_dir => 1 };
            },
        },
    );
}

sub _search_recursive {
    my ( $dir, $opts ) = @_;

    return $dir if -d File::Spec->catdir( $dir, $opts->{dir} );

    opendir my $dh, $dir or return;
    my @dirs = readdir $dh;
    closedir $dh;
    return unless @dirs;

    my ( @child_dirs, @child_files );
    for my $d (@dirs) {
        if ( -d File::Spec->catdir( $dir, $d ) ) {
            push @child_dirs, $d;
        }
        else {
            push @child_files, $d;
        }
    }

    return $opts->{no_dir}->($dir)
        if $opts->{check_no_dir}->( \@child_files );

    for my $d (@child_dirs) {
        next if $d =~ m/^\.*$/;
        $d = File::Spec->catdir( $dir, $d );
        my $theme_dir = _search_recursive( $d, $opts );
        return $theme_dir if $theme_dir;
    }

    return;
}

sub _copy_files {
    my $args = shift;

    my $from           = $args->{from};
    my $to             = $args->{to};
    my $no_plugins_dir = $args->{no_plugins_dir};
    my $no_themes_dir  = $args->{no_themes_dir};

    my @dirs
        = ( $no_plugins_dir || $no_themes_dir )
        ? ( [] )
        : ( ['plugins'], [ 'mt-static', 'plugins' ], ['themes'], );

    for my $d (@dirs) {
        my $from_dir = File::Spec->catdir( $from, @$d );
        my $to_dir   = File::Spec->catdir( $to,   @$d );
        next unless -d $from_dir && -d $to_dir;

        my @from = File::Spec->splitdir($from);
        if ($no_plugins_dir) {
            $to_dir = File::Spec->catdir( $to_dir, 'plugins', pop @from );
        }
        elsif ($no_themes_dir) {
            $to_dir = File::Spec->catdir( $to_dir, 'themes', pop @from );
        }
        else {
            $to_dir = $to_dir;
        }

        dircopy( $from_dir, $to_dir );
    }
}

1;
