use Test;
use lib 'lib';

use Incident::Report::Nagios;

plan 1;

my $nagios_report = Incident::Report::Nagios.new();
$nagios_report.service_name = "Example_Service";

$nagios_report.service_status("UNKNOWN");
$nagios_report.short_output = "Here is some output.";
$nagios_report.add_performance_data("perf_data=1");

is $nagios_report.construct_report(), defined
