use strict;

package Crosslinker::Results;
use lib 'lib';
use Crosslinker::Links;
use Crosslinker::Proteins;
use Crosslinker::Constants;
use Crosslinker::Config;
use Crosslinker::Scoring;
use base 'Exporter';
our @EXPORT = ('print_results', 'print_results_combined', 'print_report', 'print_pymol', 'print_results_text', 'print_results_paginated');

sub print_pymol {

    my (
        $top_hits,         $mass_of_hydrogen, $mass_of_deuterium, $mass_of_carbon12,
        $mass_of_carbon13, $cut_residues,     $protien_sequences, $reactive_site,
        $dbh,              $xlinker_mass,     $mono_mass_diff,    $table,
        $repeats,          $error_ref,        $names_ref,         $xlink_mono_or_all
    ) = @_;

    my %error = %{$error_ref};
    my %names = %{$names_ref};
    if (!defined $xlink_mono_or_all) { $xlink_mono_or_all = 0 }

    #     my %modifications = modifications( $mono_mass_diff, $xlinker_mass, $reactive_site, $table );

    my $fasta = $protien_sequences;
    $protien_sequences =~ s/^>.*$/>/mg;
    $protien_sequences =~ s/\n//g;
    $protien_sequences =~ s/^.//;
    $protien_sequences =~ s/ //g;

    my @hits_so_far;
    my @mz_so_far;
    my @scan_so_far;
    my $printed_hits = 0;

    print "<div><textarea cols=80 rows=20 class='span8'>";

    my $new_line        = "\n";
    my $new_division    = "";
    my $finish_line     = "";
    my $finish_division = ", ";
    my $is_it_xlink     = 0;

    while ((my $top_hits_results = $top_hits->fetchrow_hashref)) {

#       if (
#            ( !( grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far ) && !( grep $_ eq $top_hits_results->{'mz'}, @mz_so_far ) && $repeats == 0 )
#            || ( $repeats == 1
#                 && !( grep $_ eq $top_hits_results->{'scan'}, @scan_so_far ) )
#         )

        if (
            (
                !(grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far)
             && !(grep $_ eq $top_hits_results->{'mz'},   @mz_so_far)
             && !(grep $_ eq $top_hits_results->{'scan'}, @scan_so_far)
             && $repeats == 0
             && (   ($top_hits_results->{'fragment'} =~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 2))
                 || ($top_hits_results->{'fragment'} !~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 1)))
            )
            || ($repeats == 1
                && !(grep $_ eq $top_hits_results->{'scan'}, @scan_so_far))

          )
        {

            push @hits_so_far, $top_hits_results->{'fragment'};
            push @mz_so_far,   $top_hits_results->{'mz'};
            push @scan_so_far, $top_hits_results->{'scan'};

            my @fragments = split('-', $top_hits_results->{'fragment'});
            my @unmodified_fragments =
              split('-', $top_hits_results->{'unmodified_fragment'});
            if ($top_hits_results->{'fragment'} =~ '-') {
                $is_it_xlink = 1;
                print "$new_line$new_division" . "distance xl", $printed_hits + 1, "$finish_division$new_division";
                $printed_hits = $printed_hits + 1;
                my $protein = substr($top_hits_results->{'sequence1_name'}, 1);
                $protein =~ s/\s+$//g;
                print "$new_division", $names{ $top_hits_results->{'name'} }{$protein};
                print "///"
                  . ((residue_position $unmodified_fragments[0], $protien_sequences) +
                     $error{ $top_hits_results->{'name'} }{ substr($top_hits_results->{'sequence1_name'}, 1) } +
                     $top_hits_results->{'best_x'} +
                     1)
                  . "/CA$finish_division";
                $protein = substr($top_hits_results->{'sequence2_name'}, 1);
                $protein =~ s/\s+$//g;
                print "$new_division", $names{ $top_hits_results->{'name'} }{$protein};
                print "///"
                  . ((residue_position $unmodified_fragments[1], $protien_sequences) +
                     $error{ $top_hits_results->{'name'} }{ substr($top_hits_results->{'sequence2_name'}, 1) } +
                     $top_hits_results->{'best_y'} +
                     1)
                  . "/CA&nbsp;";

            } else {
                print "$new_line$new_division" . "create ml", $printed_hits + 1, "$finish_division$new_division";
                $printed_hits = $printed_hits + 1;
                my $protein = substr($top_hits_results->{'sequence1_name'}, 1);
                $protein =~ s/\s+$//g;
                print "$new_division", $names{ $top_hits_results->{'name'} }{$protein};
                print "///"
                  . ((residue_position $unmodified_fragments[0], $protien_sequences) +
                     $error{ $top_hits_results->{'name'} }{ substr($top_hits_results->{'sequence1_name'}, 1) } +
                     $top_hits_results->{'best_x'} +
                     1)
                  . "/";
            }
            print "$finish_line";
        } else {
            push @hits_so_far, $top_hits_results->{'fragment'};
            push @mz_so_far,   $top_hits_results->{'mz'};
            push @scan_so_far, $top_hits_results->{'scan'};
        }
    }

    if ($is_it_xlink == 1) {
        print "$new_line" . "set dash_width, 5$new_line";
        print "set dash_length, 0.5$new_line";
        print "color yellow, xl*$new_line";
        print '</textarea></div>';
    } else {
        print "$new_line" . "show sticks, ml*$new_line";
        print 'cmd.hide("((byres (ml*))&(n. c,o,h|(n. n&!r. pro)))")';
        print "$new_line" . "show spheres, ml*////NZ$new_line";
        print "orient *";
        print '</textarea></div>';
    }

}

sub print_results_text {

    my (
        $top_hits,       $mass_of_hydrogen,  $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13,
        $cut_residues,   $protien_sequences, $reactive_site,     $dbh,              $xlinker_mass,
        $mono_mass_diff, $table,             $repeats,           $xlink_mono_or_all,$settings_dbh
    ) = @_;

    my $fasta = $protien_sequences;
    $protien_sequences =~ s/^>.*$/>/mg;
    $protien_sequences =~ s/\n//g;
    $protien_sequences =~ s/^.//;
    $protien_sequences =~ s/ //g;

    my @hits_so_far;
    my @mz_so_far;
    my @scan_so_far;
    my $printed_hits = 0;

    my $new_line        = "";
    my $new_division    = "";
    my $finish_line     = "\n";
    my $finish_division = ",";
    my $is_it_xlink     = 0;

    # Chain 1	Chain 2	Position1	Position2	Fragment and Position	Score	Charge	Mass	PPM	Mod

    print "$new_line#"
      . $finish_division
      . $new_division
      . "Protein (A)"
      . $finish_division
      . $new_division
      . "Protein (B)"
      . $finish_division
      . $new_division
      . "Position (A)"
      . $finish_division
      . $new_division
      . "Position (B)"
      . $finish_division
      . $new_division
      . "Sequence (A)"
      . $finish_division
      . $new_division
      . "Sequence (B)"
      . $finish_division
      . $new_division . "Score"
      . $finish_division
      . $new_division
      . "Score (alpha chain)"
      . $finish_division
      . $new_division
      . "Score (beta chain)"
      . $finish_division
      . $new_division . "PPM"
      . $finish_division
      . $new_division . "+"
      . $finish_division
      . $new_division
      . "Reaction"
      . $finish_division
      . $new_division . "Frac"
      . $finish_division
      . $new_division
      . "Scan  (L)"
      . $finish_division
      . $new_division
      . "Scan (H)"
      . $finish_division
      . $new_division
      . "Monolink Mass"
      . $finish_division
      . $new_division . "Mod"
      . $finish_division
      . $new_division
      . "Common Ions"
      . $finish_division
      . $new_division
      . "Cross-linked Ions"
      . $finish_division
      . $new_division
      . "Neutral Losses"
      . $finish_division
      . $new_division
      . "No. of Peptide-A Ions"
      . $finish_division
      . $new_division
      . "No. of Peptide-B Ions"
      . $finish_division
      . $new_division . "% TIC"
      . $finish_division
      . $new_division
      . "Max Ion Series Length"
      . $finish_division
      . $new_division
      . "Max alpha-B Ion Series Length"
      . $finish_division
      . $new_division
      . "Max alpha-Y Ion Series Length"
      . $finish_division
      . $new_division
      . "Max beta-B Ion Series Length"
      . $finish_division
      . $new_division
      . "Max beta-Y Ion Series Length"
      . $finish_division
      . $finish_line;

    while (my $top_hits_results = $top_hits->fetchrow_hashref) {

        my $data   = $top_hits_results->{'MSn_string'};
        my $top_10 = $top_hits_results->{'top_10'};
        my @masses = split "\n", $data;

        if (
            (
                !(grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far)
             && !(grep $_ eq $top_hits_results->{'mz'}, @mz_so_far)
             && !(grep $_ eq $top_hits_results->{'name'} . $top_hits_results->{'scan'}, @scan_so_far)
             && $repeats == 0
             && (   ($top_hits_results->{'fragment'} =~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 2))
                 || ($top_hits_results->{'fragment'} !~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 1)))
            )
            || (
                $repeats == 1
                && (   ($top_hits_results->{'fragment'} =~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 2))
                    || ($top_hits_results->{'fragment'} !~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 1)))
            )
          )
        {

            push @hits_so_far, $top_hits_results->{'fragment'};
            push @mz_so_far,   $top_hits_results->{'mz'};
            push @scan_so_far, $top_hits_results->{'name'} . $top_hits_results->{'scan'};
            my $rounded = sprintf("%.3f", $top_hits_results->{'ppm'});
            my @fragments = split('-', $top_hits_results->{'fragment'});
            my @unmodified_fragments =
              split('-', $top_hits_results->{'unmodified_fragment'});
            if ($top_hits_results->{'fragment'} =~ '-') {
                print "$new_line$new_division", $printed_hits + 1, "$finish_division$new_division";
                if (
                    substr($top_hits_results->{'sequence1_name'}, 1) lt substr($top_hits_results->{'sequence2_name'}, 1)
                  )
                {
                    print "$new_division", substr($top_hits_results->{'sequence1_name'}, 1), $finish_division;
                    print "$new_division", substr($top_hits_results->{'sequence2_name'}, 1), $finish_division;
                    print $new_division,
                      ((residue_position $unmodified_fragments[0], $protien_sequences) +
                        $top_hits_results->{'best_x'} +
                        1), $finish_division;
                    print $new_division
                      . ((residue_position $unmodified_fragments[1], $protien_sequences) +
                         $top_hits_results->{'best_y'} +
                         1),
                      $finish_division;
                    print $new_division . $unmodified_fragments[0] . $finish_division;
                    print $new_division . $unmodified_fragments[1] . "$finish_division";
                    print "$top_hits_results->{'score'}$finish_division$new_division";
                    print
"$top_hits_results->{'best_alpha'}$finish_division$new_division$top_hits_results->{'best_beta'}$finish_division$new_division";
                } else {
                    print "$new_division", substr($top_hits_results->{'sequence2_name'}, 1), $finish_division;
                    print "$new_division", substr($top_hits_results->{'sequence1_name'}, 1), $finish_division;
                    print $new_division
                      . ((residue_position $unmodified_fragments[1], $protien_sequences) +
                         $top_hits_results->{'best_y'} +
                         1),
                      $finish_division;
                    print $new_division,
                      ((residue_position $unmodified_fragments[0], $protien_sequences) +
                        $top_hits_results->{'best_x'} +
                        1), $finish_division;
                    print $new_division . $unmodified_fragments[1] . "$finish_division";
                    print $new_division . $unmodified_fragments[0] . $finish_division;
                    print "$top_hits_results->{'score'}$finish_division$new_division";
                    print
"$top_hits_results->{'best_beta'}$finish_division$new_division$top_hits_results->{'best_alpha'}$finish_division$new_division";
                }
                print "$rounded$finish_division";
                print "$new_division$top_hits_results->{'charge'}$finish_division";
                print "$new_division$top_hits_results->{'name'}$finish_division";
                print "$new_division$top_hits_results->{'fraction'}$finish_division";
                print "$new_division$top_hits_results->{'scan'}$finish_division";
                if (defined $top_hits_results->{'d2_scan'}) {
                    print "$new_division$top_hits_results->{'d2_scan'}$finish_division";
                } else {
                    print "$new_division$finish_division";
                }
                print $new_division;

                print $new_division, $top_hits_results->{'monolink_mass'}, $finish_division;

                if ($top_hits_results->{'no_of_mods'} > 1) {
                    print "$top_hits_results->{'no_of_mods'} x ";

                }

                # 		warn "Scan = $top_hits_results->{'scan'} ";
                my %modifications =
                  modifications($mono_mass_diff, $xlinker_mass, $reactive_site, $top_hits_results->{'name'}, $settings_dbh);
                print $modifications{ $top_hits_results->{'modification'} }{Name};
                print $finish_division;

                print $new_division, $top_hits_results->{'matched_common'},    $finish_division;
                print $new_division, $top_hits_results->{'matched_crosslink'}, $finish_division;

                my $target = "H2O";
                my $count_h2o = () = $top_10 =~ /$target/g;
                $target = "NH3";
                my $count_nh3 = () = $top_10 =~ /$target/g;

                my $c;

                print $new_division, $count_nh3 + $count_h2o, $finish_division;
                if (
                    substr($top_hits_results->{'sequence1_name'}, 1) lt substr($top_hits_results->{'sequence2_name'}, 1)
                  )
                {
                    $target = "&#945";
                    $c = () = $top_10 =~ /$target/g;
                    print $new_division. $c . $finish_division;
                    $target = "&#946";
                    $c = () = $top_10 =~ /$target/g;
                    print $new_division. $c . $finish_division;
                } else {
                    $target = "&#946";
                    $c = () = $top_10 =~ /$target/g;
                    print $new_division. $c . $finish_division;
                    $target = "&#945";
                    $c = () = $top_10 =~ /$target/g;
                    print $new_division. $c . $finish_division;
                }
                my $rounded = sprintf("%.2f",
                          ($top_hits_results->{'matched_abundance'} + $top_hits_results->{'d2_matched_abundance'}) /
                            ($top_hits_results->{'total_abundance'} + $top_hits_results->{'d2_total_abundance'})) * 100;
                print $new_division, $rounded, $finish_division;

            } else {
                print "$new_line$new_division", $printed_hits + 1, "$finish_division$new_division";
                print "$new_division", substr($top_hits_results->{'sequence1_name'}, 1), $finish_division;
                print "$new_division", "N/A", $finish_division;
                print $new_division,
                  ((residue_position $unmodified_fragments[0], $protien_sequences) + $top_hits_results->{'best_x'} + 1),
                  $finish_division;
                print "$new_division", "N/A", $finish_division;
                print $new_division . $unmodified_fragments[0] . $finish_division;
                print "$new_division", "N/A", $finish_division;
                print "$top_hits_results->{'score'}$finish_division$new_division";
                print "$top_hits_results->{'best_alpha'}$finish_division$new_division";

                if (defined $top_hits_results->{'best_beta'}) {
                    print "$top_hits_results->{'best_beta'}$finish_division$new_division";
                } else {
                    print "$finish_division$new_division";
                }
                print "$rounded$finish_division";
                print "$new_division$top_hits_results->{'charge'}$finish_division";
                print "$new_division$top_hits_results->{'name'}$finish_division";
                print "$new_division$top_hits_results->{'fraction'}$finish_division";
                print "$new_division$top_hits_results->{'scan'}$finish_division$new_division";
                if (defined $top_hits_results->{'d2_scan'}) {
                    print "$new_division$top_hits_results->{'d2_scan'}$finish_division";
                } else {
                    print "$new_division$finish_division";
                }

                print $new_division;

                print $new_division, $top_hits_results->{'monolink_mass'}, $finish_division;

                my %modifications =
                  modifications($mono_mass_diff, $xlinker_mass, $reactive_site, $top_hits_results->{'name'}, $settings_dbh);
                if ($top_hits_results->{'no_of_mods'} > 1) {
                    print "$top_hits_results->{'no_of_mods'} x ";

                }
                print "$modifications{$top_hits_results->{'modification'}}{Name}";
                print $finish_division;

                print $new_division, $top_hits_results->{'matched_common'},    $finish_division;
                print $new_division, $top_hits_results->{'matched_crosslink'}, $finish_division;

                my $target = "H2O";
                my $count_h2o = () = $top_10 =~ /$target/g;
                $target = "NH3";
                my $count_nh3 = () = $top_10 =~ /$target/g;

                my $c;

                print $new_division, $count_nh3 + $count_h2o, $finish_division;
                $target = "&#945";
                $c = () = $top_10 =~ /$target/g;
                print $new_division. $c . $finish_division;
                $target = "&#946";
                $c = () = $top_10 =~ /$target/g;
                print $new_division. $c . $finish_division;

                my $rounded = sprintf("%.2f",
                          ($top_hits_results->{'matched_abundance'} + $top_hits_results->{'d2_matched_abundance'}) /
                            ($top_hits_results->{'total_abundance'} + $top_hits_results->{'d2_total_abundance'})) * 100;
                print $new_division, $rounded, $finish_division;

            }
            $printed_hits = $printed_hits + 1;

            my $max_ion_series_length_ref = find_ion_series($top_10);
            my %max_ion_series_length     = %{$max_ion_series_length_ref};
            if (substr($top_hits_results->{'sequence1_name'}, 1) lt substr($top_hits_results->{'sequence2_name'}, 1)
                || $top_hits_results->{'fragment'} !~ '-')
            {
                print $new_division, $max_ion_series_length{'total'},   $finish_division;
                print $new_division, $max_ion_series_length{'alpha_b'}, $finish_division;
                print $new_division, $max_ion_series_length{'alpha_y'}, $finish_division;
                print $new_division, $max_ion_series_length{'beta_b'},  $finish_division;
                print $new_division, $max_ion_series_length{'beta_y'},  $finish_division;
            } else {
                print $new_division, $max_ion_series_length{'total'},   $finish_division;
                print $new_division, $max_ion_series_length{'beta_b'},  $finish_division;
                print $new_division, $max_ion_series_length{'beta_y'},  $finish_division;
                print $new_division, $max_ion_series_length{'alpha_b'}, $finish_division;
                print $new_division, $max_ion_series_length{'alpha_y'}, $finish_division;

            }
            print $finish_line;

        } else {
            push @hits_so_far, $top_hits_results->{'fragment'};
            push @mz_so_far,   $top_hits_results->{'mz'};
            push @scan_so_far, $top_hits_results->{'name'} . $top_hits_results->{'scan'};
        }
    }

}

sub print_results_paginated {

    my (
        $top_hits,          $mass_of_hydrogen,  $mass_of_deuterium, $mass_of_carbon12,  $mass_of_carbon13,
        $cut_residues,      $protien_sequences, $reactive_site,     $dbh,               $xlinker_mass,
        $mono_mass_diff,    $table,             $mass_seperation,   $repeats,           $scan_repeats,
        $no_tables,         $max_hits,          $monolink,          $static_mod_string, $varible_mod_string,
        $xlink_mono_or_all, $decoy,             $no_links,          $settings_dbh
    ) = @_;

    if (!defined $max_hits)          { $max_hits          = 0 }
    if (!defined $no_links)          { $no_links          = 0 }      #Tells us we are in single scan mode.
    if (!defined $xlink_mono_or_all) { $xlink_mono_or_all = 0 }
    if (!$repeats)                   { $repeats           = 0 }
    if (!$no_tables)                 { $no_tables         = 0 }
    if (!defined $monolink)          { $monolink          = 0 }
    if (!defined $decoy)             { $decoy             = 'No' }
    if ($decoy eq 'true') { $decoy = 'Yes' }

    # warn $decoy;

     my %modifications  = modifications($mono_mass_diff, $xlinker_mass, $reactive_site, $table, $settings_dbh);

    my $fasta = $protien_sequences;
    $protien_sequences =~ s/^>.*$/>/mg;
    $protien_sequences =~ s/\n//g;
    $protien_sequences =~ s/^.//;
    $protien_sequences =~ s/ //g;

   

    
	print '<table class="table table-striped"><tr><td></td><td>Score</td><td>MZ</td><td>Charge</td><td>PPM</td><td colspan="2">Fragment&nbsp;and&nbsp;Position</td>';
        if ($monolink == 1) { print '<td>Monolink Mass</td>'; }
        print '<td class="table table-striped">Modifications</td><td>Sequence&nbsp;Names</td><td>Fraction<td>Scan&nbsp;(Light)<br/>Scan&nbsp;(Heavy)</td></td></td><td>View</td>';
        if ($decoy eq 'Yes') { print '<td>FDR</td>' }
        print '</tr>';
    
    my $printed_hits = 0;
    while ( my $top_hits_results = $top_hits->fetchrow_hashref)
    {

        my $target = "&#945";
        my $alpha_ions = () = $top_hits_results->{'top_10'} =~ /$target/g;
        $target = "&#946";
        my $beta_ions = () = $top_hits_results->{'top_10'} =~ /$target/g;
        my $min_ions = -1
          ; #Allows for you to filter a minium number of ions for A and B chains, but is surprisingly ineffective at improving confidence.


            my $rounded = sprintf("%.3f", $top_hits_results->{'ppm'});

            print "<tr><td>", $printed_hits + 1, "</td><td>$top_hits_results->{'max_score'}</td><td>";
            if ($no_links == 1) { print $top_hits_results->{'mz'}; }
            else {
                print
	    "<a href='view_scan.pl?table=$table&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}'>$top_hits_results->{'mz'}</a>";
            }

            print "</td><td>$top_hits_results->{'charge'}+</td><td>$rounded</td>";

            my @fragments = split('-', $top_hits_results->{'fragment'});
            my @unmodified_fragments =
              split('-', $top_hits_results->{'unmodified_fragment'});
            if ($top_hits_results->{'fragment'} =~ '-') {
                $printed_hits = $printed_hits + 1;
                print "<td>";
                if ($no_links == 0) {
                    print "<a href='view_peptide.pl?table=$table&peptide=$fragments[0]-$fragments[1]'>";
                }
                print residue_position $unmodified_fragments[0], $top_hits_results->{'sequence1'};
                print ".", $fragments[0], "&#8209;";
                print residue_position $unmodified_fragments[1], $top_hits_results->{'sequence2'};
                print ".", $fragments[1] . "</td><td>", $top_hits_results->{'best_x'} + 1, "&#8209;",
                  $top_hits_results->{'best_y'} + 1;
                if ($no_links == 0) { print "</a>" }
                print "</td><td>";
            } else {
                $printed_hits = $printed_hits + 1;
                print "<td>";
                if ($no_links == 0) { print "<a href='view_peptide.pl?table=$table&peptide=$fragments[0]'>" }
                print residue_position $unmodified_fragments[0], $protien_sequences;
		if ($modifications{$top_hits_results->{'modification'}}{Name} eq 'loop link') 
		  {                 print ".",               $unmodified_fragments[0];	}
		else 
		  {                 print ".",               $fragments[0];	}
                print "&nbsp;</td><td>", $top_hits_results->{'best_x'} + 1;
		if ($modifications{$top_hits_results->{'modification'}}{Name} eq 'loop link') 
		  { print "&#8209;" , index ($fragments[0],'X')+1				}         
                if ($no_links == 0) { print "</a>" }
                print "</td><td>";
            }
            if ($monolink == 1) {
                if ($top_hits_results->{'monolink_mass'} eq 0) {
                    print 'N/A</td><td>';
                } else {
                    print "$top_hits_results->{'monolink_mass'}</td><td>";
                }
            }
            if ($top_hits_results->{'no_of_mods'} > 1) {
                print "$top_hits_results->{'no_of_mods'} x";
            }
            print " $modifications{$top_hits_results->{'modification'}}{Name}</td><td>",
              substr($top_hits_results->{'sequence1_name'}, 1);
            if ($top_hits_results->{'fragment'} =~ '-') {
                print " - ", substr($top_hits_results->{'sequence2_name'}, 1);
            }
            print "</td><td> $top_hits_results->{'fraction'}</td><td>";
            if ($top_hits_results->{'scan'} == '-1') {
                if (defined $top_hits_results->{'d2_scan'}) {
                    print
"      <a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'max_score'}&heavy=0' class='screenshot' rel='view_thub.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'max_score'}&heavy=0'>Light Scan</a>";
                    print
" <br/><a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'max_score'}&heavy=1' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'max_score'}&heavy=1'>Heavy Scan</a>";
                } else {
                    print
"      <a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'max_score'}&heavy=0' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'max_score'}&heavy=0'>Light Scan</a>";
                }
            } else {
                if (defined $top_hits_results->{'d2_scan'}) {
                    print
"      <a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'max_score'}&heavy=0' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'max_score'}&heavy=0'>$top_hits_results->{'scan'}</a>";
                    print
" <br/><a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'max_score'}&heavy=1' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'max_score'}&heavy=1'>$top_hits_results->{'d2_scan'}</a>";
                } else {
                    print
"      <a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'max_score'}&heavy=0' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'max_score'}&heavy=0'>$top_hits_results->{'scan'}</a>";
                }
            }
            if (defined $top_hits_results->{'precursor_scan'} && $top_hits_results->{'precursor_scan'} ne '') {
                print "<br/>(";
                print
"<a  href='view_precursor.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'precursor_scan'}&mass=$top_hits_results->{'mz'}'  class='screenshot'  rel='view_precursor_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'precursor_scan'}&mass=$top_hits_results->{'mz'}'>";
                print $top_hits_results->{'precursor_scan'};
                print "</a>)";
            }
            print "</td><td>";
            print_ms2_link(
                           $top_hits_results->{'MSn_string'}, $top_hits_results->{'d2_MSn_string'},
                           $top_hits_results->{'fragment'},   $top_hits_results->{'modification'},
                           $top_hits_results->{'best_x'},     $top_hits_results->{'best_y'},
                           $xlinker_mass,                     $mono_mass_diff,
                           $top_hits_results->{'top_10'},     $reactive_site,
                           $table
            );

            print "</td>";

            my $fdr = sprintf("%.2f", $top_hits_results->{'FDR'} * 100);
            if ($decoy eq 'Yes') { print "<td>$fdr%</td>" }
            print "</tr>";

    }
    print '</table>';

}

sub print_results {

    my (
        $top_hits,          $mass_of_hydrogen,  $mass_of_deuterium, $mass_of_carbon12,  $mass_of_carbon13,
        $cut_residues,      $protien_sequences, $reactive_site,     $dbh,               $xlinker_mass,
        $mono_mass_diff,    $table,             $mass_seperation,   $repeats,           $scan_repeats,
        $no_tables,         $max_hits,          $monolink,          $static_mod_string, $varible_mod_string,
        $xlink_mono_or_all, $decoy,             $no_links,          $settings_dbh
    ) = @_;

    if (!defined $max_hits)       			{ $max_hits          = 0 }
    if (!defined $no_links || $no_links eq '')          { $no_links          = 0 }      #Tells us we are in single scan mode.
    if (!defined $xlink_mono_or_all) 			{ $xlink_mono_or_all = 0 }
    if (!$repeats)                   			{ $repeats           = 0 }
    if (!$no_tables)                 			{ $no_tables         = 0 }
    if (!defined $monolink || $monolink eq '')          { $monolink          = 0 }
    if (!defined $decoy)             			{ $decoy             = 'No' }
    if ($decoy eq 'true') 				{ $decoy = 'Yes' }

    # warn $decoy;

#    warn $settings_dbh;

    my %modifications  = modifications($mono_mass_diff, $xlinker_mass, $reactive_site, $table, $settings_dbh);

    my $fasta = $protien_sequences;
    $protien_sequences =~ s/^>.*$/>/mg;
    $protien_sequences =~ s/\n//g;
    $protien_sequences =~ s/^.//;
    $protien_sequences =~ s/ //g;

    my @hits_so_far;
    my @mz_so_far;
    my @scan_so_far;
    my $printed_hits  = 0;
    my $fdr           = 0;
    my $fdr_non_decoy = 0;
    my $fdr_decoy     = 0;

    if ($no_tables == 0) {
        print
'<table class="table table-striped"><tr><td></td><td>Score</td><td>MZ</td><td>Charge</td><td>PPM</td><td colspan="2">Fragment&nbsp;and&nbsp;Position</td>';
        if ($monolink == 1) { print '<td>Monolink Mass</td>'; }
        print
'<td class="table table-striped">Modifications</td><td>Sequence&nbsp;Names</td><td>Fraction<td>Scan&nbsp;(Light)<br/>Scan&nbsp;(Heavy)</td></td></td><td>View</td>';
        if ($decoy eq 'Yes') { print '<td>FDR</td>' }
        print '</tr>';
    }

    while (   (my $top_hits_results = $top_hits->fetchrow_hashref)
           && ($max_hits == 0 || $printed_hits < $max_hits))
    {

        my $target = "&#945";
        my $alpha_ions = () = $top_hits_results->{'top_10'} =~ /$target/g;
        $target = "&#946";
        my $beta_ions = () = $top_hits_results->{'top_10'} =~ /$target/g;
        my $min_ions = -1
          ; #Allows for you to filter a minium number of ions for A and B chains, but is surprisingly ineffective at improving confidence.

        if (   !(grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far)
            && !(grep $_ eq $top_hits_results->{'mz'},   @mz_so_far)
            && !(grep $_ eq $top_hits_results->{'scan'}, @scan_so_far)
            && ($top_hits_results->{'sequence1_name'} =~ 'decoy' || $top_hits_results->{'sequence2_name'} =~ 'decoy')
            && ($alpha_ions > $min_ions && $beta_ions > $min_ions))
        {
            $fdr_decoy = $fdr_decoy + 1;
        } elsif (   !(grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far)
                 && !(grep $_ eq $top_hits_results->{'mz'},   @mz_so_far)
                 && !(grep $_ eq $top_hits_results->{'scan'}, @scan_so_far))
        {
            $fdr_non_decoy = $fdr_non_decoy + 1;
        }

        if (
            (
                !(grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far)
             && !(grep $_ eq $top_hits_results->{'mz'},   @mz_so_far)
             && !(grep $_ eq $top_hits_results->{'scan'}, @scan_so_far)
             && (
                 !( $top_hits_results->{'sequence1_name'} =~ 'decoy' || $top_hits_results->{'sequence2_name'} =~ 'decoy'
                 )
                 || $decoy eq 'No'
             )
             && $repeats == 0
             && (   ($top_hits_results->{'fragment'} =~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 2))
                 || ($top_hits_results->{'fragment'} !~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 1)))

             && ($alpha_ions > $min_ions && $beta_ions > $min_ions)

            )
            || (
                   $repeats == 1
                && !(grep $_ eq $top_hits_results->{'scan'}, @scan_so_far)
                && $scan_repeats == 0
                && (
                    !(    $top_hits_results->{'sequence1_name'} =~ 'decoy'
                       || $top_hits_results->{'sequence2_name'} =~ 'decoy')
                    || $decoy eq 'No'
                )
            )
            || (
                   $repeats == 1
                && $scan_repeats == 1
                && (
                    !(    $top_hits_results->{'sequence1_name'} =~ 'decoy'
                       || $top_hits_results->{'sequence2_name'} =~ 'decoy')
                    || $decoy eq 'No'
                )
            )
          )
        {

            push @hits_so_far, $top_hits_results->{'fragment'};
            push @mz_so_far,   $top_hits_results->{'mz'};
            push @scan_so_far, $top_hits_results->{'scan'};
            my $rounded = sprintf("%.3f", $top_hits_results->{'ppm'});

            print "<tr><td>", $printed_hits + 1, "</td><td>$top_hits_results->{'score'}</td><td>";
            if ($no_links == 1) { print $top_hits_results->{'mz'}; }
            else {
                print
"<a href='view_scan.pl?table=$table&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}'>$top_hits_results->{'mz'}</a>";
            }

            print "</td><td>$top_hits_results->{'charge'}+</td><td>$rounded</td>";

            my @fragments = split('-', $top_hits_results->{'fragment'});
            my @unmodified_fragments =
              split('-', $top_hits_results->{'unmodified_fragment'});
            if ($top_hits_results->{'fragment'} =~ '-') {
                $printed_hits = $printed_hits + 1;
                print "<td>";
                if ($no_links == 0) {
                    print "<a href='view_peptide.pl?table=$table&peptide=$fragments[0]-$fragments[1]'>";
                }
                print residue_position $unmodified_fragments[0], $top_hits_results->{'sequence1'};
                print ".", $fragments[0], "&#8209;";
                print residue_position $unmodified_fragments[1], $top_hits_results->{'sequence2'};
                print ".", $fragments[1] . "</td><td>", $top_hits_results->{'best_x'} + 1, "&#8209;",
                  $top_hits_results->{'best_y'} + 1;
                if ($no_links == 0) { print "</a>" }
                print "</td><td>";
            } else {
                $printed_hits = $printed_hits + 1;
                print "<td>";
                if ($no_links == 0) { print "<a href='view_peptide.pl?table=$table&peptide=$fragments[0]'>" }
                print residue_position $unmodified_fragments[0], $protien_sequences;
		if ($modifications{$top_hits_results->{'modification'}}{Name} eq 'loop link') 
		  {                 print ".",               $unmodified_fragments[0];	}
		else 
		  {                 print ".",               $fragments[0];	}
                print "&nbsp;</td><td>", $top_hits_results->{'best_x'} + 1;
		if ($modifications{$top_hits_results->{'modification'}}{Name} eq 'loop link') 
		  { print "&#8209;" , index ($fragments[0],'X')+1				}         
                if ($no_links == 0) { print "</a>" }
                print "</td><td>";
            }
            if ($monolink == 1) {
                if ($top_hits_results->{'monolink_mass'} eq 0) {
                    print 'N/A</td><td>';
                } else {
                    print "$top_hits_results->{'monolink_mass'}</td><td>";
                }
            }
            if ($top_hits_results->{'no_of_mods'} > 1) {
                print "$top_hits_results->{'no_of_mods'} x";
            }

	    if ($top_hits_results->{'sequence1_name'} =~ />..\|(......)\|/  )
	      {
		 print "$modifications{$top_hits_results->{'modification'}}{Name}</td><td>";
		 print "<a href='http://www.uniprot.org/uniprot/$1'>$1</a>";
	      } else
	      {
            print " $modifications{$top_hits_results->{'modification'}}{Name}</td><td>",
              substr($top_hits_results->{'sequence1_name'}, 1);
	      }
            if ($top_hits_results->{'fragment'} =~ '-') {
	      if ($top_hits_results->{'sequence2_name'} =~ />..\|(......)\|/  )
	      {
		 print "&#8209;<a href='http://www.uniprot.org/uniprot/$1'>$1</a>";
	      } else
	      {
                print " - ", substr($top_hits_results->{'sequence2_name'}, 1);
	      }
            }
            print "</td><td> $top_hits_results->{'fraction'}</td><td>";
            if ($top_hits_results->{'scan'} == '-1') {
                if (defined $top_hits_results->{'d2_scan'}) {
                    print
"      <a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0'>Light Scan</a>";
                    print
" <br/><a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1'>Heavy Scan</a>";
                } else {
                    print
"      <a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0'>Light Scan</a>";
                }
            } else {
                if (defined $top_hits_results->{'d2_scan'}) {
                    print
"      <a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0'>$top_hits_results->{'scan'}</a>";
                    print
" <br/><a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1'>$top_hits_results->{'d2_scan'}</a>";
                } else {
                    print
"      <a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0'>$top_hits_results->{'scan'}</a>";
                }
            }
            if (defined $top_hits_results->{'precursor_scan'} && $top_hits_results->{'precursor_scan'} ne '') {
                print "<br/>(";
                print
"<a  href='view_precursor.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'precursor_scan'}&mass=$top_hits_results->{'mz'}'  class='screenshot'  rel='view_precursor_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'precursor_scan'}&mass=$top_hits_results->{'mz'}'>";
                print $top_hits_results->{'precursor_scan'};
                print "</a>)";
            }
            print "</td><td>";
            print_ms2_link(
                           $top_hits_results->{'MSn_string'}, $top_hits_results->{'d2_MSn_string'},
                           $top_hits_results->{'fragment'},   $top_hits_results->{'modification'},
                           $top_hits_results->{'best_x'},     $top_hits_results->{'best_y'},
                           $xlinker_mass,                     $mono_mass_diff,
                           $top_hits_results->{'top_10'},     $reactive_site,
                           $table
            );

#             print_xquest_link(
#                               $top_hits_results->{'MSn_string'}, $top_hits_results->{'d2_MSn_string'},
#                               $top_hits_results->{'mz'},         $top_hits_results->{'charge'},
#                               $top_hits_results->{'fragment'},   $mass_seperation,
#                               $mass_of_deuterium,                $mass_of_hydrogen,
#                               $mass_of_carbon13,                 $mass_of_carbon12,
#                               $cut_residues,                     $xlinker_mass,
#                               $mono_mass_diff,                   $reactive_site,
#                               $fasta,                            $static_mod_string,
#                               $varible_mod_string
#             );

            print "</td>";

            if (defined $top_hits_results->{'FDR'}) { $fdr = sprintf("%.2f", $top_hits_results->{'FDR'} * 100)} else { $fdr = '0'};
            if ($decoy eq 'Yes') { print "<td>$fdr%</td>" }
            print "</tr>";
        } else {
            push @hits_so_far, $top_hits_results->{'fragment'};
            push @mz_so_far,   $top_hits_results->{'mz'};
            push @scan_so_far, $top_hits_results->{'scan'};
        }
    }
    print '</table>';

}

sub print_results_combined {

    my (
        $top_hits,       $mass_of_hydrogen,    $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13,
        $cut_residues,   $protien_sequences,   $reactive_site,     $dbh,              $xlinker_mass,
        $mono_mass_diff, $mass_seperation_ref, $table,             $repeats,          $scan_repeats,
        $no_tables,      $xlink_mono_or_all,   $show_scan_image
    ) = @_;

    my %mass_seperation = %{$mass_seperation_ref};

    if (!$repeats)                   { $repeats           = 0 }
    if (!$no_tables)                 { $no_tables         = 0 }
    if (!defined $xlink_mono_or_all) { $xlink_mono_or_all = 0 }

    my $fasta = $protien_sequences;
    $protien_sequences =~ s/^>.*$/>/mg;
    $protien_sequences =~ s/\n//g;
    $protien_sequences =~ s/^.//;
    $protien_sequences =~ s/ //g;

    my @hits_so_far  = '';
    my @mz_so_far    = '';
    my @scan_so_far  = '';
    my $printed_hits = 0;

    if ($no_tables == 0) {
        print
'<table class="table table-striped"><tr><td></td><td>Score</td><td>MZ</td><td>Charge</td><td>PPM</td><td colspan="2">Fragment&nbsp;and&nbsp;Position</td><td>Modifications</td><td>Sequence&nbsp;Names</td><td>Fraction<td>Scan&nbsp;(Light)<br/>Scan&nbsp;(Heavy)</td></td></td>';
	 if ($show_scan_image != 1) { print '<td>View</td>'} ;
	print '</tr>';
    }

    while ((my $top_hits_results = $top_hits->fetchrow_hashref))    #&& ($printed_hits <= 50)
    {
        if (defined $top_hits_results->{'fragment'} && defined $top_hits_results->{'mz'} && $top_hits_results->{'scan'})
        {
            if (
                (
                    !(grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far)
                 && !(grep $_ eq $top_hits_results->{'mz'},   @mz_so_far)
                 && !(grep $_ eq $top_hits_results->{'scan'}, @scan_so_far)
                 && $repeats == 0
                 && (   ($top_hits_results->{'fragment'} =~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 2))
                     || ($top_hits_results->{'fragment'} !~ '-' && ($xlink_mono_or_all == 0 || $xlink_mono_or_all == 1))
                 )
                )
                || (   $repeats == 1
                    && !(grep $_ eq $top_hits_results->{'scan'}, @scan_so_far)
                    && $scan_repeats == 0)
                || ($repeats == 1 && $scan_repeats == 1)
              )
            {
                push @hits_so_far, $top_hits_results->{'fragment'};
                push @mz_so_far,   $top_hits_results->{'mz'};
                push @scan_so_far, $top_hits_results->{'name'} . $top_hits_results->{'scan'};
                my $rounded = sprintf("%.3f", $top_hits_results->{'ppm'});
                print "<tr><td>", $printed_hits + 1,"</td><td>";
		if ($show_scan_image != 1) { print "<a href='view_scan.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}'>";}
		print "$top_hits_results->{'score'}";
		if ($show_scan_image != 1) {print "</a>"};
		print "</td><td>$top_hits_results->{'mz'}</td><td>$top_hits_results->{'charge'}+</td><td>$rounded</td>";
                my @fragments = split('-', $top_hits_results->{'fragment'});
                my @unmodified_fragments =
                  split('-', $top_hits_results->{'unmodified_fragment'});
                if ($top_hits_results->{'fragment'} =~ '-') {
                    $printed_hits = $printed_hits + 1;
                    print "<td>";
 		    if ($show_scan_image != 1) {print "<a href='view_peptide.pl?table=$top_hits_results->{'name'}&peptide=$fragments[0]-$fragments[1]'>";}
                    print residue_position $unmodified_fragments[0], $protien_sequences;
                    print ".", $fragments[0], "&#8209;";
                    print residue_position $unmodified_fragments[1], $protien_sequences;
                    print ".", $fragments[1] . "</td><td>", $top_hits_results->{'best_x'} + 1, "&#8209;",
                      $top_hits_results->{'best_y'} + 1;
 		    if ($show_scan_image != 1) { print "</a>";}
		    print "</td><td>";
                } else {
                    $printed_hits = $printed_hits + 1;
                    print "<td>";
 		    if ($show_scan_image != 1) {print "<a href='view_peptide.pl?table=$top_hits_results->{'name'}&peptide=$fragments[0]'>";}
                    print residue_position $unmodified_fragments[0], $protien_sequences;
                    print ".", $fragments[0];
                    print "&nbsp;</td><td>", $top_hits_results->{'best_x'} + 1;
 		    if ($show_scan_image != 1) { print "</a>";}
		    print "</td><td>";
                }
                if ($top_hits_results->{'no_of_mods'} > 1) {
                    print "$top_hits_results->{'no_of_mods'} x";
                }
                my %modifications =
                  modifications($mono_mass_diff, $xlinker_mass, $reactive_site, $top_hits_results->{'name'});
                print
                  " $modifications{$top_hits_results->{'modification'}}{Name}</td><td>",
                  substr($top_hits_results->{'sequence1_name'}, 1);
                if ($top_hits_results->{'fragment'} =~ '-') {
                    print " - ", substr($top_hits_results->{'sequence2_name'}, 1);
                }
                print "</td><td>$top_hits_results->{'name'},$top_hits_results->{'fraction'}</td><td>";

		if ($show_scan_image == 1)
		{
	      print "<img src='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0'/>";
                }elsif ($top_hits_results->{'scan'} == '-1') {
                    print
"      <a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0'>Light Scan</a>";
                    print
" <br/><a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1'>Heavy Scan</a>";
                } else {
                    if (defined $top_hits_results->{'d2_scan'}) {
                        print
"      <a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0'>$top_hits_results->{'scan'}</a>";
                        print
" <br/><a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=1'>$top_hits_results->{'d2_scan'}</a>";
                    } else {
                        print
"      <a  href='view_img.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0' class='screenshot' rel='view_thumb.pl?table=$top_hits_results->{'name'}&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}&heavy=0'>$top_hits_results->{'scan'}</a>";
                    }
                }

                if ($show_scan_image != 1) {
		print "</td><td>";
		print_ms2_link(
                               $top_hits_results->{'MSn_string'}, $top_hits_results->{'d2_MSn_string'},
                               $top_hits_results->{'fragment'},   $top_hits_results->{'modification'},
                               $top_hits_results->{'best_x'},     $top_hits_results->{'best_y'},
                               $xlinker_mass,                     $mono_mass_diff,
                               $top_hits_results->{'top_10'},     $reactive_site,
                               $reactive_site,                    $top_hits_results->{'name'}
                );}

                my $varible_mod_string = '';
                my $dynamic_mods = get_mods($top_hits_results->{'name'}, 'dynamic');
                while ((my $dynamic_mod = $dynamic_mods->fetchrow_hashref)) {
                    $varible_mod_string =
                      $varible_mod_string . $dynamic_mod->{'mod_residue'} . ":" . $dynamic_mod->{'mod_mass'} . ",";
                }
                my $static_mod_string = '';
                my $fixed_mods = get_mods($top_hits_results->{'name'}, 'fixed');
                while ((my $fixed_mod = $fixed_mods->fetchrow_hashref)) {

                    $static_mod_string =
                      $static_mod_string . $fixed_mod->{'mod_residue'} . ":" . $fixed_mod->{'mod_mass'} . ",";
                }

#                 print_xquest_link(
#                                   $top_hits_results->{'MSn_string'}, $top_hits_results->{'d2_MSn_string'},
#                                   $top_hits_results->{'mz'},         $top_hits_results->{'charge'},
#                                   $top_hits_results->{'fragment'},   $mass_seperation{ $top_hits_results->{'name'} },
#                                   $mass_of_deuterium,                $mass_of_hydrogen,
#                                   $mass_of_carbon13,                 $mass_of_carbon12,
#                                   $cut_residues,                     $xlinker_mass,
#                                   $mono_mass_diff,                   $reactive_site,
#                                   $fasta,                            $static_mod_string,
#                                   $varible_mod_string
#                 );

                print "</td></tr>";
            } else {
                push @hits_so_far, $top_hits_results->{'fragment'};
                push @mz_so_far,   $top_hits_results->{'mz'};
                push @scan_so_far, $top_hits_results->{'name'} . $top_hits_results->{'scan'};
            }
        }
    }
    print '</table>';

}

sub print_report {

    my (
        $top_hits,       $mass_of_hydrogen,  $mass_of_deuterium, $mass_of_carbon12, $mass_of_carbon13,
        $cut_residues,   $protien_sequences, $reactive_site,     $dbh,              $xlinker_mass,
        $mono_mass_diff, $table,             $repeats,		 $proteinase_k,	    $settings_dbh
    ) = @_;

    my %modifications = modifications($mono_mass_diff, $xlinker_mass, $reactive_site, $table, $settings_dbh);

    my $fasta = $protien_sequences;
    $protien_sequences =~ s/^>.*$/>/mg;
    $protien_sequences =~ s/\n//g;
    $protien_sequences =~ s/^.//;
    $protien_sequences =~ s/ //g;

    my @hits_so_far;
    my @mz_so_far;
    my @scan_so_far;
    my $printed_hits = 0;

    while ((my $top_hits_results = $top_hits->fetchrow_hashref)) {
        if (
            (
                !(grep $_ eq $top_hits_results->{'fragment'}, @hits_so_far)
             && !(grep $_ eq $top_hits_results->{'mz'}, @mz_so_far)
             && $repeats == 0
            )
            || ($repeats == 1
                && !(grep $_ eq $top_hits_results->{'scan'}, @scan_so_far))
          )
        {
            print '<div style="page-break-inside: avoid; page-break-after: always;">';
            if (defined $top_hits_results->{'d2_scan'}) {
                print
"<img src='view_img.pl?table=$table&scan=$top_hits_results->{'scan'}&d2_scan=$top_hits_results->{'d2_scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}'/><br/><br/>";
            } else {
                print
"<img src='view_img.pl?table=$table&scan=$top_hits_results->{'scan'}&fraction=$top_hits_results->{'fraction'}&score=$top_hits_results->{'score'}'/><br/><br/>";
            }
            push @hits_so_far, $top_hits_results->{'fragment'};
            push @mz_so_far,   $top_hits_results->{'mz'};
            push @scan_so_far, $top_hits_results->{'scan'};
            my $rounded = sprintf("%.3f", $top_hits_results->{'ppm'});
            my @fragments = split('-', $top_hits_results->{'fragment'});
            my @unmodified_fragments =
              split('-', $top_hits_results->{'unmodified_fragment'});

            if ($top_hits_results->{'fragment'} =~ '-') {
                $printed_hits = $printed_hits + 1;
                print "Sequence: <a href='view_peptide.pl?table=$table&peptide=$fragments[0]-$fragments[1]'>";
                print residue_position $unmodified_fragments[0], $top_hits_results->{'sequence1'};
                print ".", $fragments[0], "&#8209;";
                print residue_position $unmodified_fragments[1], $top_hits_results->{'sequence2'};
                print ".", $fragments[1] . "</a><br/>Cross link position: ", $top_hits_results->{'best_x'} + 1, "-",
                  $top_hits_results->{'best_y'} + 1, "</br>";
            } else {
                print "<td><a href='view_peptide.pl?table=$table&peptide=$fragments[0]'>";
                print residue_position $unmodified_fragments[0], $protien_sequences;
                print ".", $fragments[0];
                print "&nbsp;</td><td>", $top_hits_results->{'best_x'} + 1, "</a></td><td>";
            }
            print
"Score: $top_hits_results->{'score'} <br/>M/Z: $top_hits_results->{'mz'}<br/>Charge: $top_hits_results->{'charge'}+<br/>PPM: $rounded<br/>";
            print "Modifications: ";
            if ($top_hits_results->{'no_of_mods'} > 1) {
                print "$top_hits_results->{'no_of_mods'} x";
            }
            print " $modifications{$top_hits_results->{'modification'}}{Name}<br/>";
            print "Proteins: ", substr($top_hits_results->{'sequence1_name'}, 1);
            if ($top_hits_results->{'fragment'} =~ '-') {
                print " - ", substr($top_hits_results->{'sequence2_name'}, 1);
            }
            print "<br/>Fraction: $top_hits_results->{'fraction'}<br/>";

            print "</div>";
        } else {
            push @hits_so_far, $top_hits_results->{'fragment'};
            push @mz_so_far,   $top_hits_results->{'mz'};
            push @scan_so_far, $top_hits_results->{'scan'};
        }

    }

}
