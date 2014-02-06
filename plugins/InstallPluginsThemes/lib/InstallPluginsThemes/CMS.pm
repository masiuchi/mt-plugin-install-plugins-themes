package InstallPluginsThemes::CMS;
use strict;
use warnings;

use File::Spec;
use File::Temp qw/ tempdir /;

# Max download size.
our $UA_MAX_SIZE = 10_000_000;

sub install_plugin_theme {
    my $app = shift;

    # Check
    return $app->errtrans('Invalid request.')
        unless $app->request_method eq 'POST' && $app->validate_magic;
    return $app->permission_denied unless $app->user->is_superuser;

    # Set IDs.
    $app->setup_filtered_ids
        if $app->param('all_selected');
    my @id = $app->param('id');

    require MT::PluginTheme;
    my @plugin = MT::PluginTheme->load( { id => \@id } );
    for my $p (@plugin) {

        # Create temporary directory.
        my $dir = tempdir(
            DIR => $app->config->TempDir,
            $MT::DebugMode ? () : ( CLEANUP => 1 )
        );

        # Generate download URL of zip file.
        my $download_url = _get_url_to_zip( $p->download_url );
        MT->log( 'Donwload URL: ' . $download_url ) if $MT::DebugMode;
        next unless $download_url;
        my ($file) = ( $download_url =~ m/\/([^\/]+)$/ );
        my $download_file = File::Spec->catfile( $dir, $file );

        # Download zip file.
        my $ua = $app->new_ua( { max_size => $UA_MAX_SIZE } );
        my $res
            = $ua->get( $download_url, ':content_file' => $download_file );

        next unless $res->is_success;

        # Unzip zip file.
        my $unzip_cmd = "cd $dir; unzip $file";
        MT->log( 'Unzip command: ' . $unzip_cmd ) if $MT::DebugMode;
        my $ret = `$unzip_cmd`;

        if ( my $plugin_root = _search_plugin_root($dir) ) {

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
        elsif ( my $theme_root = _search_theme_root($dir) ) {

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
        my $ua = MT->new_ua( { max_size => $UA_MAX_SIZE } );
        my $res = $ua->get($url);
        return unless $res->is_success;
        my $content = $res->decoded_content;
        return unless $content;
        my @zip_url = ( $content =~ m/<a href="([^"]+\.zip)"/g );
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

    return $dir if -d File::Spec->catdir( $dir, 'plugins' );

    opendir my $dh, $dir or return;
    my @dirs = readdir $dh;
    closedir $dh;
    return unless @dirs;

    my @child_dirs = grep { -d File::Spec->catdir( $dir, $_ ) } @dirs;
    my @child_files = grep { !( -d File::Spec->catdir( $dir, $_ ) ) } @dirs;

    for my $f (@child_files) {
        if ( $f =~ m/\.pl$/ || $f =~ 'config\.yaml$' ) {
            return { plugin_root => $dir, no_plugins_dir => 1 };
        }
    }

    for my $d (@child_dirs) {
        next if $d =~ m/^\.*$/;
        $d = File::Spec->catdir( $dir, $d );
        my $plugin_dir = _search_plugin_root($d);
        return $plugin_dir if $plugin_dir;
    }

    return;
}

# Search theme root directory.
sub _search_theme_root {
    my $dir = shift;

    return $dir if -d File::Spec->catdir( $dir, 'themes' );

    opendir my $dh, $dir or return;
    my @dirs = readdir $dh;
    closedir $dh;
    return unless @dirs;

    my @child_dirs = grep { -d File::Spec->catdir( $dir, $_ ) } @dirs;
    my @child_files = grep { !( -d File::Spec->catdir( $dir, $_ ) ) } @dirs;

    for my $f (@child_files) {
        if ( $f =~ 'theme\.yaml$' ) {
            return { theme_root => $dir, no_themes_dir => 1 };
        }
    }

    for my $d (@child_dirs) {
        next if $d =~ m/^\.*$/;
        $d = File::Spec->catdir( $dir, $d );
        my $theme_dir = _search_theme_root($d);
        return $theme_dir if $theme_dir;
    }

    return;
}

# Copy files of plugin or theme from temporary directory to MT directory.
sub _copy_files {
    my $args = shift;

    my $from           = $args->{from};
    my $to             = $args->{to};
    my $no_plugins_dir = $args->{no_plugins_dir};
    my $no_themes_dir  = $args->{no_themes_dir};

    my $delim = $^O eq 'MSWin32' ? "\\" : '/';
    my @dirs
        = ( $no_plugins_dir || $no_themes_dir )
        ? ( [] )
        : ( ['plugins'], [ 'mt-static', 'plugins' ], ['themes'], );

    for my $d (@dirs) {
        my $from_dir = File::Spec->catdir( $from, @$d );
        my $to_dir   = File::Spec->catdir( $to,   @$d );
        next unless -d $from_dir && -d $to_dir;
        my $cmd
            = $no_plugins_dir
            ? "cp -rf ${from_dir} ${to_dir}${delim}plugins${delim}"
            : $no_themes_dir
            ? "cp -rf ${from_dir} ${to_dir}${delim}themes${delim}"
            : "cp -rf ${from_dir}${delim}* ${to_dir}${delim}";
        MT->log( 'copy command: ' . $cmd ) if $MT::DebugMode;
        `$cmd`;
    }
}

1;
