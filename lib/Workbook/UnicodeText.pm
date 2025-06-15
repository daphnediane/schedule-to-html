use v5.38.0;    ## no critic (Modules::ProhibitExcessMainComplexity)
use utf8;
use Feature::Compat::Class;

class Workbook::UnicodeText :isa(Workbook) {    ## no critic (Modules::RequireEndWithOne,Modules::RequireExplicitPackage)
    use English     qw( -no_match_vars );
    use Carp        qw{ croak };
    use File::Slurp qw{ read_file };
    use File::Spec  qw{};
    use Readonly    qw{ Readonly };

    Readonly our $TXT_SUFFIX => qr{ [.] (?: txt | csv ) \z }xmsi;

    field %sheet_to_handle;
    field @handle_to_info;
    field $is_initialized;

    method release () {
        %sheet_to_handle = 0;
        @handle_to_info  = 0;
        $is_initialized  = 1;
    }

    method init() {
        return if defined $is_initialized;
        $is_initialized = 1;

        my $filename = $self->get_filename();
        if ( -d $filename ) {
            my @base_names
                = grep { $_ =~ $TXT_SUFFIX }
                File::Spec->no_upwards(
                read_dir( $filename, err_mode => qw{ croak } ) );
            my @priority;
            my @other;
            my %name_to_root;
            foreach my $base_name ( sort @base_names ) {
                ( my $root = $base_name ) =~ s{ $TXT_SUFFIX }{}xms;
                if ( $root =~ m{ \A \d+ \z }xms ) {
                    $root = 0 + $root;
                    $handle_to_info[ $root ] //= {
                        file => $base_name,
                        root => $root,
                    };
                    continue;
                } ## end if ( $root =~ m{ \A \d+ \z }xms)
                $name_to_root{ $base_name } = $root;
                if ( $root eq qw{ schedule } ) {
                    push @priority, $base_name;
                }
                else {
                    push @other, $base_name;
                }
            } ## end foreach my $base_name ( sort...)
            my $next_idx = 0;
            foreach my $base_name ( @priority, @other ) {
                my $root = $name_to_root{ $base_name };
                ++$next_idx while defined $handle_to_info[ $next_idx ];
                $handle_to_info[ $next_idx ] //= {
                    file => File::Spec->catfile( $filename, $base_name ),
                    root => $root,
                };
                $sheet_to_handle{ lc $root } //= $next_idx;
                $sheet_to_handle{ $root } //= $next_idx;
                $sheet_to_handle{ $base_name } = $next_idx;
                ++$next_idx;
            } ## end foreach my $base_name ( @priority...)
        } ## end if ( -d $filename )

        my $handle = 0;
        $sheet_to_handle{ Schedule } = $handle;
        $sheet_to_handle{ schedule } = $handle;
        @handle_to_info[ $handle ]   = {
            file   => $filename,
            handle => $handle,
        };
        return;

    } ## end sub init

    method _load_handle ( $handle ) {
        return unless defined $handle;
        return if $handle->{ line_cache };
        $handle->{ line_cache } = read_file(
            $handle->{ file },
            { binmode => q{:raw:encoding(utf16):crlf}, array_ref => 1 }
        );
        return $handle;
    } ## end sub _load_handle

    method _lookup_sheet_num ( $sheet ) {
        $self->init() unless defined $is_initialized;

        # Direct number
        if ( $sheet =~ m{\A \d+ \z}xms ) {
            return 0 + $sheet if defined $handle_to_info[ 0 + $sheet ];
        }

        # Full name
        my $handle_num = $sheet_to_handle{ $sheet };
        return $handle_num if defined $handle_num;

        # Short name
        $sheet =~ s{ $TXT_SUFFIX }{}xms;
        $handle_num = $sheet_to_handle{ $sheet };

        # Lowercase name
        $sheet      = lc $sheet;
        $handle_num = $sheet_to_handle{ $sheet };
        return $handle_num if defined $handle_num;

        # Fallback to zerosheet
        return 0 if $sheet eq q{schedule};

        return;
    } ## end sub _lookup_sheet_num

    method find_sheet_handle ( $sheet //= 0 ) {
        my $handle_num = _lookup_sheet_num( $sheet );
        return unless defined $handle_num;
        my $handle = $handle_to_info[ $handle_num ];
        return unless defined $handle;
        $self->_load_handle( $handle );
        return $handle;
    } ## end sub find_sheet_handle

    method get_line_range ( $sheet_handle ) {
        return unless defined $sheet_handle;
        my $lines = $sheet_handle->{ line_cache };
        return unless defined $lines;
        my $high = scalar @{ $lines };
        --$high;
        return ( 0, $high );
    } ## end sub get_line_range

    method get_line ( $sheet_handle, $line_no ) {

        my $lines = $sheet_handle->{ line_cache };
        return unless defined $lines;

        return if $line_no >= scalar @{ $lines };
        my $line = $lines->[ $line_no ];
        return unless defined $line;

        my $full_line = $line;
        my @raw       = split m{\t}xms, $line;
        my @res;
        while ( @raw ) {
            my $piece = shift @raw;
            if ( $piece =~ m{ \A " }xms ) {
                my $full = $piece;
                while ( $full
                    !~ m{ \A " (?: [^"]++ | (?: "" )++ )* " (?:\n\r?+|\r\n?+)?+ \z }xms
                ) {
                    if ( !@raw ) {
                        chomp $full_line;
                        die
                            qq{Unable to process: [${full}]\nin line: ${full_line}\n};
                    }
                    $full .= shift @raw;
                } ## end while ( $full !~ ...)
                $full =~ s{ \A " }{}xms;
                $full =~ s{ (?:\n\r?+|\r\n?+)?+ \z }{}xms;
                $full =~ s{ " \z }{}xms;
                $full =~ s{ "" }{"}xmsg;
                push @res, $full;
            } ## end if ( $piece =~ m{ \A " }xms)
            else {
                push @res, $piece;
            }
        } ## end while ( @raw )
        return \@res;

    } ## end sub get_line
} ## end package Workbook::UnicodeText

1;
