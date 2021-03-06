package Mojolicious::Command::cron::watch;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw(slurp decode);
use Mojolicious::Plugin::Config;
use Filesys::DiskUsage qw/du/;
use LutimModel;
use Switch;

has description => 'Watch the files directory and take action when over quota';
has usage => sub { shift->extract_usage };

sub run {
    my $c = shift;

    my $config = Mojolicious::Plugin::Config->parse(decode('UTF-8', slurp 'lutim.conf'), 'lutim.conf');

    if (defined($config->{max_total_size})) {
        my $total = du(qw/files/);

        if ($total > $config->{max_total_size}) {
            if (defined($config->{policy_when_full})) {
                say "[LUTIm cron job watch] Files directory is over quota ($total > ".$config->{max_total_size}.")";
                switch ($config->{policy_when_full}) {
                    case 'warn' {
                        say "[LUTIm cron job watch] Please, delete some files or increase quota (".$config->{max_total_size}.")";
                    }
                    case 'stop-upload' {
                        open (my $fh, '>', 'stop-upload') or die ("Couldn't open stop-upload: $!");
                        close($fh);
                        say '[LUTIm cron job watch] Uploads are stopped. Delete some images and the stop-upload file to reallow uploads.';
                    }
                    case 'delete' {
                        say '[LUTIm cron job watch] Older files are being deleted';
                        do {
                            for my $img (LutimModel::Lutim->select('WHERE path IS NOT NULL AND enabled = 1 ORDER BY created_at ASC LIMIT 50')) {
                                unlink $img->path() or warn "Could not unlink ".$img->path.": $!";
                                $img->update(enabled => 0);
                            }
                        } while (du(qw/files/) > $config->{max_total_size});
                    }
                    else {
                        say '[LUTIm cron job watch] Unrecognized policy_when_full option: '.$config->{policy_when_full}.'. Aborting.';
                    }
                }
            } else {
                say "[LUTIm cron job watch] Files directory over quota ($total > ".$config->{max_total_size}.") but no configured policy_when_full option!" ;
            }
        } else {
            unlink 'stop-upload' if (-f 'stop-upload');
        }
    } else {
        say "[LUTIm cron job watch] No max_total_size found in the configuration file. Aborting.";
    }
}

=encoding utf8

=head1 NAME

Mojolicious::Command::cron::watch - Delete IP addresses from database after configured delay

=head1 SYNOPSIS

  Usage: script/lutim cron watch

=cut

1;
