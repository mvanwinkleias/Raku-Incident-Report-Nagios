#!/usr/bin/perl6

=begin pod

=head1 NAME

Incident::Report::Nagios - Creates Nagios plugin output

=head1 SYNOPSIS

=begin code
use Incident::Report::Nagios;
my $nagios_report = Incident::Report::Nagios.new(
	service_name => "Some_service",
);

$nagios_report.short_output = "First line of output";
$nagios_report.add_long_output(
	"Any number of subsequent lines of output, "
		~ "but note that buffers"
);
$nagios_report.add_long_output("may have a limited size");

$nagios_report.add_performance_data("First part of performance data");
$nagios_report.add_performance_data("Second part of performance data, which");
$nagios_report.add_performance_data("may have continuation lines, too");
say $nagios_report.construct_report();

=end code

=head1 DESCRIPTION

=head1 METHODS

=end pod

# See this:
# https://design.raku.org/S11.html#Versioning
# you can have yuor Incident::Report::Nagios:auth<user.university>, I can have my Incident::Report::Nagios:auth<tadzik> and it's all fine :)

class Incident::Report::Nagios
{
	# SERVICE_NAME SERVICE_STATUS: short_status [ | first_perf_data ]
	# [optional long_status_output ...
	# long_status_output ] [ | rest_of_perf_data ]
		
	has %.service_states = 
		'OK' => 0,
		'WARNING' => 1,
		'CRITICAL' => 2,
		'UNKNOWN' => 3,
	;
	
	has Str $.service_name is rw;

	has Str $.service_status
		is default('OK')
		is rw;
	multi method service_status (Str $new_status)
	{
		if ( ! (%!service_states{$new_status}:exists) )
		{
			say "Bad status: " ~ $new_status;
			return Nil;
		}
		$!service_status = $new_status;
		return $!service_status;
	}
=begin pod

=head2 method bump_service_status
    method bump_service_status() returns Str

Implements the following status transition table:

=begin table
Old State | In State  | New State
=================================
OK        |  UNKNOWN  |  UNKNOWN 
OK        |  WARNING  |  WARNING 
OK        |  CRITICAL |  CRITICAL
WARNING   |  OK       |  WARNING 
WARNING   |  UNKNOWN  |  WARNING
WARNING   |  CRITICAL |  CRITICAL
ANY       |  CRITICAL |  CRITICAL
=end table

I might need to examine this for better tables: https://docs.perl6.org/language/tables

=end pod
	method bump_service_status (Str $new_status)
	{
		if (
				$new_status eq 'CRITICAL'
			|| (
				$new_status eq 'WARNING'
				&& $!service_status ne 'CRITICAL'
			)
			|| ( $new_status eq 'UNKNOWN'
				&& $!service_status eq 'OK'
			)
		)
		{
			$!service_status = $new_status;
		}
		return $!service_status;
	}

	has Str $.short_output is rw;

	# These are optional
	has Str @.performance_data;
	has Str @.long_output;

	method add_long_output(Str $new_long_output)
	{
		@!long_output.push($new_long_output);
	}
	
	method add_performance_data(Str $new_performance_data)
	{
		@!performance_data.push($new_performance_data);
	}
	
	method find_problems
	{
		my @found_problems;
		
		# Todo: Find out why we couldn't do $!service_name.defined()
		# and the best way to handle this
		if (! ($!service_name).defined())
		{
			push @found_problems, "service_name is undefined.";
		}
		
		if ( ! ($!service_status).defined() )
		{
			push @found_problems, "service_status is undefined.";
		}
		else
		{
			if ( ! (%!service_states{$!service_status}:exists) )
			{
				push @found_problems, $!service_status ~ " is not a valid service status.";
			}
		}
		
		if ( ! ($!short_output).defined() )
		{
			push @found_problems, "short_output is undefined.";
		}
		
		return @found_problems;
	}
	
	method construct_report
	{
		my @found_problems = self.find_problems();
		if (@found_problems.elems() != 0)
		{
			return Nil;
		}
		
		my Str $report;
		
		$report ~=
			$!service_name
			~ " " ~ $!service_status ~ ": "
			~ $!short_output
		;

		my @performance_data_copy = @!performance_data;

		if ( @performance_data_copy.elems() != 0)
		{
			$report ~= " | " ~ @performance_data_copy.shift();
		}
		
		if (@performance_data_copy.elems() != 0
			|| (@!long_output.elems()) != 0
		)
		{
			$report ~= "\n";
		}
		
		if ( (@!long_output).elems != 0)
		{
			$report ~= (@!long_output).join("\n");
		}
		
		if (@performance_data_copy.elems() != 0)
		{
			$report ~= ' | ' ~ @performance_data_copy.join("\n");
		}
		
		return $report;
	}
}

# my $basic_nagios_report = test_basic_things;
# test_more_things($basic_nagios_report);

#mimic_nagios_plugin_guideline_output();

sub test_basic_things
{

	my $nagios_report = Incident::Report::Nagios.new();

	# $nagios_report.long_output().push("Something");
	$nagios_report.service_name = "TEST_SERVICE";

	$nagios_report.service_status("OK");
	$nagios_report.short_output = "Looks good!";
	$nagios_report.add_long_output("Here's long output 1.");
	$nagios_report.add_long_output("Here's long output 2.");
	$nagios_report.add_performance_data("Performance Data 1");
	$nagios_report.add_performance_data("Performance Data 2");
	$nagios_report.add_performance_data("Performance Data 3");

	test_more_things($nagios_report);
	
	return $nagios_report;
}

sub test_more_things (Incident::Report::Nagios $nagios_report)
{
	# say $nagios_report.perl();

	# say $nagios_report.find_problems();
	say $nagios_report.construct_report();
	say "Bumping it to UNKNOWN.";
	$nagios_report.bump_service_status('UNKNOWN');
	say $nagios_report.construct_report();
}

=begin pod

It would appear that there is some ambiguity with how a plugin should
output things.

This document:

=item https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/4/en/pluginapi.html 

shows things in the format of
   DISK OK - free space: /2909 MB

Where

=item http://nagios-plugins.org/doc/guidelines.html

Says:

  SERVICE STATUS:

Which hints that the output SHOULD look like:

  DISK OK: free space: /2909 MB

This is the format that I've chosen.  I've run into problems where performance value
data with colons in the name have been (incorrectly?) interpreted:

  SERVICE STATUS - UPSMib::SomeThing = 5

where that Might have been split thus: "SERVICE STATUS - UPSMib:" , and "UPSMib"
might have been the status.  I don't have a full workup on this, but after moving
to use a ":" instead of a "-", I was getting the desired result.
  
So, we'll try to mimic the output from http://nagios-plugins.org/doc/guidelines.html

  SERVICE STATUS: First line of output | First part of performance data
  Any number of subsequent lines of output, but note that buffers
  may have a limited size | Second part of performance data, which
  may have continuation lines, too

Even then, this is not "well defined", but we'll try to mimic it.

=end pod

sub mimic_nagios_plugin_guideline_output
{
	my $nagios_report = Incident::Report::Nagios.new();
	$nagios_report.service_name = "SERVICE";

	$nagios_report.service_status("OK");
	$nagios_report.short_output = "First line of output";
	$nagios_report.add_long_output(
		"Any number of subsequent lines of output, "
		~ "but note that buffers"
	);
	$nagios_report.add_long_output("may have a limited size");
	
	$nagios_report.add_performance_data("First part of performance data");
	$nagios_report.add_performance_data("Second part of performance data, which");
	$nagios_report.add_performance_data("may have continuation lines, too");

	say $nagios_report.construct_report();
}
