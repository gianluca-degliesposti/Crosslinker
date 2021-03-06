#!/usr/bin/perl -w

########################
#                      #
# Modules	       #
#                      #
########################

use strict;
use CGI;
use CGI::Carp qw ( fatalsToBrowser );
use DBI;

use lib 'lib';
use Crosslinker::HTML;
use Crosslinker::Data;

my $query    = new CGI;
my $table    = $query->param('table');
my $new_name = $query->param('name');

my $settings_dbh = connect_settings;

print_page_top_bootstrap('Rename');

if (defined $new_name) {
    if ($new_name eq "") { $new_name = "None" }
    my $settings_sql = $settings_dbh->prepare("
					UPDATE settings 
					SET description=?
					WHERE name=?
					");

    $settings_sql->execute($new_name, $table);
    print "<p>Return to <a href='results.pl'>results</a>?</p>";
} else {

    my $table_list = $settings_dbh->prepare(
                        "SELECT name, description, finished FROM settings WHERE name=? ORDER BY length(name) DESC, name DESC");
    $table_list->execute($table);

    my $table_name = $table_list->fetchrow_hashref;

    print "<p>Please give new name for $table?</p>";
    print "<p><form style='margin:1em 1em 1em 4em;'>
	<input type='hidden' name='table' value='" . $table . "'/>
	New name: <input type='text' name='name' value='"
      . $table_name->{'description'} . "' />
       <input type='submit' value='Submit'></form></p>"
}
print_page_bottom_bootstrap;

exit;

