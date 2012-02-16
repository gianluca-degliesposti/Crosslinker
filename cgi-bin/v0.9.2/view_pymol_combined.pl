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
use Crosslinker::Links;
use Crosslinker::Scoring;
use Crosslinker::Constants;

########################
#                      #
# Import CGI Varibles  #
#                      #
########################

my $query = new CGI;
my @table;

my $order;

if ( defined $query->param('order') ) {
    $order = $query->param('order');
}

########################
#                      #
# Connect to database  #
#                      #
########################

my $results_dbh  = DBI->connect( "dbi:SQLite:dbname=db/results",  "", "", { RaiseError => 1, AutoCommit => 1 } );
my $settings_dbh = DBI->connect( "dbi:SQLite:dbname=db/settings", "", "", { RaiseError => 1, AutoCommit => 1 } );

########################
#                      #
# Constants            #
#                      #
########################

my ( $mass_of_deuterium, $mass_of_hydrogen, $mass_of_proton, $mass_of_carbon12, $mass_of_carbon13, $no_of_fractions, $min_peptide_length, $scan_width ) = constants;
my %protein_residuemass = protein_residuemass();

########################
#                      #
# Summary Gen          #
#                      #
########################

my $settings = $settings_dbh->prepare("SELECT name FROM settings");
$settings->execute();
my $combined_tables;
my $param;

print_page_top_fancy('Summary');
while ( ( my $data_set = $settings->fetchrow_hashref ) ) {
    if ( defined $query->param( $data_set->{'name'} ) ) {
        push @table, $data_set->{'name'};
        $param = $param . "&$data_set->{'name'}=true";
    }
}

my $SQL_query;
for ( my $table_no = 0 ; $table_no < @table ; $table_no++ ) {
    $SQL_query = $SQL_query . "SELECT * FROM settings WHERE name = ? UNION ";
}
$SQL_query = substr( $SQL_query, 0, -6 );

$settings = $settings_dbh->prepare($SQL_query);
$settings->execute(@table);

print_heading('Settings');

my %mass_seperation_hash;

my ( $name, $desc, $cut_residues, $protein_sequences, $reactive_site, $mono_mass_diff, $xlinker_mass, $decoy, $ms2_da, $ms1_ppm, $is_finished, $mass_seperation );
my $protein_sequences_combined;
print "<table>";

while ( ( my @settings = $settings->fetchrow_array ) ) {
    ( $name, $desc, $cut_residues, $protein_sequences, $reactive_site, $mono_mass_diff, $xlinker_mass, $decoy, $ms2_da, $ms1_ppm, $is_finished, $mass_seperation ) = @settings;
    $protein_sequences_combined = $protein_sequences_combined . $protein_sequences;
    $mass_seperation_hash{$name} = $mass_seperation;

    if ( $is_finished != '-1' ) { print '<tr><td colspan="4" style="color:red">Warning: ' . $name . ' Data analysis not finished</td></tr>'; }

    print "<tr><td colspan='4' style='font-weight: bold;'>$name</td></tr>
<tr><td style='font-weight: bold;'>Name:</td><td>$name</td><td style='font-weight: bold;'>Description</td><td>$desc</td></tr>
<tr><td style='font-weight: bold;'>Cut:</td><td>$cut_residues</td><td style='font-weight: bold;'>Xlink Site</td><td>$reactive_site</td></tr>
<tr><td style='font-weight: bold;'>Xlinker Mass:</td><td>$xlinker_mass</td><td style='font-weight: bold;'>Monolink</td><td>$mono_mass_diff</td></tr>
<tr><td style='font-weight: bold;'>MS1 tollerance:</td><td>$ms1_ppm PPM</td><td style='font-weight: bold;'>MS2 tollerance</td><td>$ms2_da Da</td></tr>
";

}
print "</table>";

$settings->finish();
$settings_dbh->disconnect();

print_heading('Crosslink Matches');
my $top_hits;
$SQL_query = "";

if ( defined $order ) {
    for ( my $table_no = 0 ; $table_no < @table ; $table_no++ ) {
        $SQL_query = $SQL_query . "SELECT * FROM (SELECT * FROM results WHERE name=? AND fragment LIKE '%-%' ORDER BY score DESC) UNION ALL ";
    }
    $SQL_query = substr( $SQL_query, 0, -10 );
    $top_hits = $results_dbh->prepare( $SQL_query . " ORDER BY sequence1_name, sequence2_name LIMIT 50" );    #nice injection problem here, need to sort
} else {
    for ( my $table_no = 0 ; $table_no < @table ; $table_no++ ) {
        $SQL_query = $SQL_query . "SELECT * FROM results WHERE name=? AND fragment LIKE '%-%' UNION ALL ";
    }
    $SQL_query = substr( $SQL_query, 0, -10 );
    $top_hits = $results_dbh->prepare( "SELECT * FROM (" . $SQL_query . ") ORDER BY score DESC " );    #nice injection problem here, need to sort
}
$top_hits->execute(@table);
print_pymol( $top_hits, $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues, $protein_sequences_combined, $reactive_site, $results_dbh, $xlinker_mass, $mono_mass_diff, \%mass_seperation_hash, 'table', 1, 0, 0 );

$SQL_query = "";
print_heading('Top Scoring Monolink Matches');
if ( defined $order ) {
    for ( my $table_no = 0 ; $table_no < @table ; $table_no++ ) {
        $SQL_query = $SQL_query . "SELECT * FROM (SELECT * FROM results WHERE name=? AND fragment NOT LIKE '%-%' ORDER BY score DESC) UNION ALL ";
    }
    $SQL_query = substr( $SQL_query, 0, -10 );
    $top_hits = $results_dbh->prepare( $SQL_query . " ORDER BY sequence1_name, sequence2_name" );    #nice injection problem here, need to sort
} else {
    for ( my $table_no = 0 ; $table_no < @table ; $table_no++ ) {
        $SQL_query = $SQL_query . "SELECT * FROM results WHERE name=? AND fragment NOT LIKE '%-%' UNION ALL ";
    }
    $SQL_query = substr( $SQL_query, 0, -10 );
    $top_hits = $results_dbh->prepare( $SQL_query . " ORDER BY score DESC" );    #nice injection problem here, need to sort
}
$top_hits->execute(@table);
print_pymol( $top_hits, $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13, $cut_residues, $protein_sequences_combined, $reactive_site, $results_dbh, $xlinker_mass, $mono_mass_diff, \%mass_seperation_hash, 'table', 1, 0, 0 );

print_page_bottom_fancy;
$top_hits->finish();
$results_dbh->disconnect();
exit;
