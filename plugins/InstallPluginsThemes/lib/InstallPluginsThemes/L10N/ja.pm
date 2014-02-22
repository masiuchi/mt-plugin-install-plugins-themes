package InstallPluginsThemes::L10N::ja;
use strict;
use warnings;
use base qw( InstallPluginsThemes::L10N );

our %Lexicon = (

    # config.yaml
    'Install plugins or themes from Movable Type Plugins And Themes Directory.'
        => 'Movable Type プラグイン&テーマディレクトリから、プラグイン／テーマをインストールします。',

    # lib/MT/PluginTheme.pm
    'Plugin and Theme'       => 'プラグインとテーマ',
    'Plugins and Themes'     => 'プラグインとテーマ',
    'Install'                => 'インストール',
    'Plugin or Theme Name'   => 'プラグイン／テーマ名',
    'Plugin or Theme Author' => '開発者',
    'Plugin'                 => 'プラグイン',
    'Theme'                  => 'テーマ',
    'Plugins Only'           => 'プラグインのみ',
    'Themes Only'            => 'テーマのみ',

    # tmpl/listing/plugin_theme_list_header.tmpl
    'Please check the license by yourself before installing.' =>
        'お手数ですが、インストール前に各自でライセンス確認をお願い致します。',
    'You have successfully installed the plugin(s) and/or theme(s).' =>
        'プラグインまたはテーマをインストールしました。',
);

1;
