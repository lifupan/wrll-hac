# This perl module handles various HAC server transactions and
# provides useful utility functions

package HelixUtils;

use strict;
use warnings;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

#use Data::Dumper;

$VERSION     = 1.00;
@ISA         = qw(Exporter);
@EXPORT      = qw( setLogLvl setLogOptions logMsg execCmd hacGetCSRFToken hacGenerateNamedTarget hacGetKeyExpiration hacGetDeviceStatus hacGetWRSToken hacRegisterTarget getDefaultSdkVer getDefaultSdkName setDefaultSdkCfgData getDefaultSdkCfgData getDefaultHacServer getDefaultBoardName );
@EXPORT_OK   = ();
%EXPORT_TAGS = ( DEFAULT => [qw( &setLogLvl &setLogOptions &logMsg &execCmd &hacGetCSRFToken &hacGenerateNamedTarget &hacGetKeyExpiration &hacGetDeviceStatus &hacGetWRSToken &hacRegisterTarget &getDefaultSdkVer &getDefaultSdkName &setDefaultSdkCfgData &getDefaultSdkCfgData &getDefaultHacServer &getDefaultBoardName )] );

use JSON::PP;
use File::Temp qw/ tempdir /;
use File::Spec::Functions;
use File::Copy;
use Sys::Syslog qw(:standard :macros);

#use Data::Dumper;

my $logLvl = 0;

# Flag to indicate if the logMsg() API should exit on when a message
# is flagged fatal
my $logExtOnFatalF = 1;

# The stream to use for log messages, if specified. Will override
# local behavior.
my $logOutStream;
undef $logOutStream;

# Flag to tell the logMsg() function to call syslog. Assumes caller
# has previously setup syslog() properly.
my $logUseSyslogF = 0;

my $tmpDir = tempdir( CLEANUP => 1 );

# The expected location for SDK name and version data
my $sdkVerFile = catfile( File::Spec->rootdir(), "etc", "default", "sdkVersion.txt" );
my $sdkNameFile = catfile( File::Spec->rootdir(), "etc", "default", "sdkName.txt" );
my $sdkDevCfgFile = catfile( File::Spec->rootdir(), "etc", "default", "device_mgr.cfg" );
my $serverCfgFile = catfile( File::Spec->rootdir(), "etc", "default", "hacServer.cfg" );
my $backupServerCfgFile = catfile( File::Spec->rootdir(), "etc", "default", "hacServer.bak" );
my $sysBoardNameFile = catfile( File::Spec->rootdir(), "sys", "devices", "virtual", "dmi", 
				"id", "board_name" );

# A routine to execute a command and return the results. First arg is
# the shell command string to evaluate. A scalar reference can be
# passed as a 2nd arg to get return status
sub execCmd
{
    my $cmd = shift;
    my $status = shift;

    # Always capture stderr
    my @rslt = `$cmd 2>&1`;
    chomp @rslt;

    ${ $status } = $? if defined $status;

    logMsg( "> $cmd\n  " . join( "\n  ", @rslt ) . "\n",
	    { lvl => 2 } );

    # Let the caller decide if they want a scalar or an array
    return wantarray ? @rslt : join( "\n", @rslt );
}

# A routine to set the log level used by logMsg()
sub setLogLvl
{
    $logLvl = shift;
}

# Routine to set the logMsg() function options
sub setLogOptions
{
    my $options = shift;

    if ( exists ${ $options }{ lvl } )
    {
	$logLvl = ${ $options }{ lvl };
    }

    if ( exists ${ $options }{ fatalFlag } )
    {
	$logExtOnFatalF = ${ $options }{ fatalFlag };
    }

    if ( exists ${ $options }{ out } )
    {
	$logOutStream = ${ $options }{ out };
    }

    if ( exists ${ $options }{ useSyslog } )
    {
	$logUseSyslogF = ${ $options }{ useSyslog };
    }
}

# A routine to print output / control where it goes relative to the
# log level which is set for the program. Log level for the program
# may be:
#   -1 = No output
#    0 = Errors only
#    1 = Verbose messages
#    2 = Debug
#    3 = Debug+
#
#  First argument is a string to be logged. 
#
#  Second argument (optional) is a hash containing the log message
#  settings. The hash may contain:
#   { 
#     out = <>,          # <> is some type of file handle
#     lvl => [ 0 - 2 ],  # Use log level specified
#     fatal => 1,        # Die after reporting the error
#     debug => 1         # Debug log level
#   }
#    -- If the level is not specified the message is assumed to be log level 0. 
#    -- { lvl } will be the log level of the message
#    -- When { fatal } is defined the message is printed to stderr and 
#       the program exits with error status
#    -- { out } may be used to specify a file descriptor to send output 
#       which overrides the default. Out will be closed before exiting 
#       the program.
#    -- { debug } may be specified instead of lvl => 2 to indicate a debug 
#       message
#
#  NOTE: If the debug flag is set all messages are output regardless
#  of the log level
sub logMsg
{
    my $msg = shift;
    my $args = shift;
    my $lvl = 0;

    if ( exists ${ $args }{ lvl } )    
    {
	$lvl = ${ $args }{ lvl };
    }
    elsif ( exists ${ $args }{ debug } ) 
    {
	$lvl = 2;
    }

    # Pick STDOUT or STDERR based on message level
    #   lvl = -1, no output
    #   lvl = 0, STDERR
    #   lvl > 0, STDOUT
    #   if ${ $args }{ out }, then use specified descriptor
    my $out = *STDERR;

    if ( defined $logOutStream )
    {
	$out = $logOutStream;
    }
    elsif ( exists ${ $args }{ out } )
    {
	$out = ${ $args }{ out };
    }
    else
    {
	$out = *STDOUT if ( $lvl > 0 );
    }
    
    if ( exists ${ $args }{ fatal } ||
	 ( ( $logLvl > -1 ) && ( $lvl <= $logLvl ) ) )
    {
	if ( $logUseSyslogF )
	{
	    # Map levels
	    my $sLvl = "info";	    

	    if ( $lvl == 0 )
	    {
		$sLvl = "error" ;
	    }
	    elsif ( $lvl >= 2 )
	    {
		$sLvl = "info";
	    }
	    
	    $msg =~ s/[\n\r]+$//;
	    $msg =~ s/[\n\r]+/;/g;
	    syslog( $sLvl, "%s", $msg );
	}
	else
	{
	    print $out "$msg";
	}
    }
    
    if ( exists ${ $args }{ fatal } )
    {
	close( $out ) if ( exists ${ $args }{ out } );
	exit( -1 ) if ( $logExtOnFatalF );
    }
}

# Routine to execute a CURL request to the HAC server 
# Arg 1: Curl Command
# Returns: Hash of decoded JSON data
sub execServerRequest
{
    my $cmd = shift;
    my $r;

    my $data = execCmd( $cmd, \$r );

    if ( $r || ( $data =~ m|^\s*$| ) )
    {
	# If the server returns an error string in the JSON data there
	# will be a nested hash when it gets parsed, so we need to
	# return a structre that higher-level functions can handle
	# consistently
	return { error => { failed => 1 } };
    }
    
    $data = decode_json( $data );    
    
    return $data;
}


# Routine to get the CRSF token from the HAC server
#  Arg 1: HAC server
#  Arg 2: SCALAR REF to result status, 0 = success, else ERROR
#  Arg 3: SCALAR REF for error string
#  Returns: CSRF token string
sub hacGetCSRFToken
{
    my $hacServer = shift;
    my $rslt = shift;
    my $rsltStr = shift;

    # HAC server request command
    my $cmd = 
	"curl https://$hacServer/csrfToken -k -s " . 
	"-c $tmpDir/cookies.txt -b $tmpDir/cookies.txt 2>&1";
    
    # Error to return if the request fails
    my $errMsg = "ERROR: Getting CSRF token failed!";

    my $href = execServerRequest( $cmd );
    my %data = %{ $href };

    if ( exists $data{ error } )
    {
	if ( exists $data{ error }{ message } )
	{
	    ${ $rsltStr } = $data{ error }{ message };
	}
	else
	{
	    ${ $rsltStr } = $errMsg;
	}

	${ $rslt } = -1;
	return "";
    }

    ${ $rslt } = 0;
    return $data{ _csrf };
}

# Routine to generate a named target on the HAC server
sub hacGenerateNamedTarget
{
    my $hacServer = shift;
    my $boardName = shift;
    my $sdkName = shift;
    my $sdkVer = shift;
    my $tokenCSRF = shift;

    my $rslt = shift;
    my $rsltStr = shift;    

   # Generate a target with the specified name
   my $cmd = 
	"curl -X POST -k " .
	"-H \"x-csrf-token: $tokenCSRF\" " .
	"https://$hacServer/api/v1/registration " .
	"-H \"Content-Type: application/json\" " .
	"-d '" .
	encode_json( { name => $boardName, SDKKey => $sdkName, 
		       SDKVersion => $sdkVer } ) . "' ".
	"-c $tmpDir/cookies.txt -b $tmpDir/cookies.txt -s 2>&1";
    
    # Error to return if the request fails
    my $errMsg = "ERROR: Creating target [ $boardName ] " . 
	"on server [ $hacServer ] failed!";

    my $href = execServerRequest( $cmd );
    my %data = %{ $href };

    if ( exists $data{ error } )
    {
	if ( exists $data{ error }{ message } )
	{
	    ${ $rsltStr } = $data{ error }{ message };
	}
	else
	{
	    ${ $rsltStr } = $errMsg if ( $rsltStr );
	}

	${ $rslt } = -1;
	return "";
    }

    ${ $rslt } = 0;
    return ( $data{ registrationKey }, $data{ uid }, $data{ serverURL } );
}

# Routine to get a token expiration time
sub hacGetKeyExpiration
{
    my $hacServer = shift;
    my $devRegKey = shift;
    my $tokenCSRF = shift;

    my $rslt = shift;
    my $rsltStr = shift;    

    # HAC server request command
    my $cmd = 
	"curl -X GET -k -H \"x-csrf-token: $tokenCSRF\" " .
	"https://$hacServer/api/v1/registration/$devRegKey " .
	"-H \"Content-Type: application/json\" " .
	" -c $tmpDir/cookies.txt -b $tmpDir/cookies.txt -s 2>&1";    

    # Error to return if the request fails
    my $errMsg = "ERROR: Can't get expiration key time!";

    my $href = execServerRequest( $cmd );
    my %data = %{ $href };

    if ( exists $data{ error } )
    {
	if ( exists $data{ error }{ message } )
	{
	    ${ $rsltStr } = $data{ error }{ message };
	}
	else
	{
	    ${ $rsltStr } = $errMsg if ( $rsltStr );
	}

	${ $rslt } = -1;
	return "";
    }

    ${ $rslt } = 0;
    return ( $data{ status }, $data{ expire_in } );
}

# Routine to get query status of a device
sub hacGetDeviceStatus
{
    my $hacServer = shift;
    my $devId = shift;
    my $tokenCSRF = shift;

    my $rslt = shift;
    my $rsltStr = shift;

    # HAC server request command
    my $cmd = 
	"curl -X POST -k -s " .
	"-H \"x-csrf-token: $tokenCSRF\" " .
	"https://$hacServer/api/v1/registration/actions " .
	"-H \"Content-Type: application/json\" " .
	"-d '" .
	encode_json( { action => "getDeviceStatus", deviceId => "$devId" } ) .
	"' -c $tmpDir/cookies.txt -b $tmpDir/cookies.txt 2>&1"; 

    # Error to return if the request fails
    my $errMsg = 
	"ERROR: Querying Device [ $devId ] on " .
	"server [ $hacServer ] failed!";

    my $href = execServerRequest( $cmd );
    my %data = %{ $href };

    if ( exists $data{ error } )
    {
	if ( exists $data{ error }{ message } )
	{
	    ${ $rsltStr } = $data{ error }{ message };
	}
	else
	{
	    ${ $rsltStr } = $errMsg if ( $rsltStr );
	}

	${ $rslt } = -1;
	return "";
    }

    ${ $rslt } = 0;
    return $data{ status };
}

# Routine to get query status of a device
sub hacGetWRSToken
{
    my $hacServer = shift;
    my $usrName = shift;
    my $usrPassword = shift;
    my $tokenCSRF = shift;

    my $rslt = shift;
    my $rsltStr = shift;    

    # HAC server request command
    my $cmd = 
	"curl -X POST -k -u $usrName:$usrPassword https://$hacServer/api/v1/authorize " .
        "-H \"Content-Type: application/json\" -H \"x-csrf-token: $tokenCSRF\" " .
        "-c $tmpDir/cookies.txt -b $tmpDir/cookies.txt -s 2>&1";

    # Error to return if the request fails
    my $errMsg = "ERROR: Getting WRS token failed!";

    my $href = execServerRequest( $cmd );
    my %data = %{ $href };

    if ( exists $data{ error } )
    {
	if ( exists $data{ error }{ message } )
	{
	    ${ $rsltStr } = $data{ error }{ message };
	}
	else
	{
	    ${ $rsltStr } = $errMsg;
	}

	${ $rslt } = -1;
	return "";
    }

    ${ $rslt } = 0;
    return $data{ token };
}

sub hacRegisterTarget
{
    my $hacServer = shift;
    my $usrName = shift;
    my $usrPassword = shift;
    my $boardName = shift;
    my $sdkName = shift;
    my $sdkVer = shift;
    my $tokenCSRF = shift;
    my $tokenWRS = shift;

    my $rslt = shift;
    my $rsltStr = shift;    

    # HAC server request command
    my $cmd = 
	"curl -X POST -k -H \"Authorization: Bearer $tokenWRS\" " .
        "-H \"x-csrf-token: $tokenCSRF\" https://$hacServer/api/v1/devices " .
        "-H \"Content-Type: application/json\" -d '" .
	encode_json( { name => $boardName, SDKKey => $sdkName, SDKVersion => $sdkVer } ) .
	"' -c $tmpDir/cookies.txt -b $tmpDir/cookies.txt -s 2>&1";

    # Error to return if the request fails
    my $errMsg = "ERROR: Creating target [ $boardName ] on server [ $hacServer ] failed!";

    my $href = execServerRequest( $cmd );
    my %data = %{ $href };

    if ( exists $data{ error } )
    {
	if ( exists $data{ error }{ message } )
	{
	    ${ $rsltStr } = $data{ error }{ message };
	}
	else
	{
	    ${ $rsltStr } = $errMsg;
	}

	${ $rslt } = -1;
	return "";
    }

    ${ $rslt } = 0;
    return ( $data{ uid }, $data{ serverUrl } );
}

# Routine to read the SDK version from the standard file
sub getDefaultSdkVer 
{
    my $f;
    open( $f, "<", $sdkVerFile ) or
	return;
	
    my $data = <$f>;
    close( $f );

    # File should be only 1 line, which has the version of the SDK
    chomp( $data );

    return $data;
}

# Routine to read the SDK and board name from the standard file
sub getDefaultSdkName
{
    my $sdkName;
    my $boardName;

    undef $sdkName;
    undef $boardName;

    my $f;
    if ( open( $f, "<", $sdkNameFile ) )
    {
	my @data = <$f>;
	close( $f );
	chomp( @data );
	
	if ( 1 <= scalar @data )
	{
	    $sdkName = $data[ 0 ];
	}
	
	if ( 2 == scalar @data )
	{
	    $boardName = $data[ 1 ];
	}
    }

    return ( $sdkName, $boardName );
} 

# Routine to write the SDK config to the default file
sub setDefaultSdkCfgData
{
    my $cfgData = shift;

    # Backup any existing config file
    if ( -e $sdkDevCfgFile )
    {
	move( $sdkDevCfgFile, $backupServerCfgFile );
    }

    my $f;
    open( $f, ">", $sdkDevCfgFile ) or
	return -1;
    
    print $f $cfgData;
    
    close( $f );
    return 0;
} 

# Routine to read and return the SDK config from the default file
sub getDefaultSdkCfgData 
{
    my $cfgData = shift;
    my $data;

    my $f;
    open( $f, "<", $sdkDevCfgFile ) or
	return -1;
    
    $data = <$f>;
    close( $f );

    chomp( $data );

    ${ $cfgData } = $data;
    return 0;
} 

# Routine to get the default HAC server name
sub getDefaultHacServer 
{
    my $f;
    my $data;
    undef $data;

    if ( open( $f, "<", $serverCfgFile ) )
    {
	$data = <$f>;
	chomp( $data );
	close( $f );
    }

    return $data;
}

# Routine to get the default board name that has been specified, or
# generate one from the MAC of a network interface
sub getDefaultBoardName
{

    my ( $sdkName, $boardName ) = getDefaultSdkName();

    unless ( $boardName )
    {
	# Append the last 3 octets of a mac to the board name
	my $data = execCmd( "ifconfig" );
	
	my $ha = $data;
	$ha =~ s|.*HWaddr (([A-Fa-f0-9]{2}:){3})(([A-Fa-f0-9]{2}:?){3}).*|$3|sm;
	$ha =~ s|:||g;

	my $prefix = "board";
	my $f;

	if ( open( $f, "<", $sysBoardNameFile ) )
	{
	    $prefix = <$f>;
	    close( $f );

	    chomp( $prefix );

	    # Remove leading & ending white space
	    $prefix =~ s|^\s+||;
	    $prefix =~ s|\s+$||;

	    # Turn white space to '_'
	    $prefix =~ s|\s+|_|g;
	}

	$boardName = $prefix . "_" . $ha;
    }

    return $boardName;
}

# Must return a true value
1;
