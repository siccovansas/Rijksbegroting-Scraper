#!/usr/bin/env perl

# Script to convert the output of the scraped data from rijksbegroting.nl into
# csv files which can be used for the Nederlandse Rijksbegroting Visualisatie.

use strict;
use warnings;
use JSON;
use Text::CSV;


######################
# OPTIONS
######################
# The years that need to be processed.
my @years = (2012, 2013, 2014);

# The departments are sorted based on an awesome mix of Roman numerals and characters. This order needs
# to be manually specified to keep the data nicely sorted when saving it to the csv files.
my @custom_order = qw(I IIA IIB III IV V VI VII VIII IX IXA IXB X XI XII XIII XV XVI XVII XVIII A B C F H J);
my %order = map +($custom_order[$_] => $_), 0 .. $#custom_order;

######################
# FUNCTIONS
######################
# Custom sorting function for the Roman numeral/character mix of the departments.
sub custom_sort {
        my @x = split('_', $a);
        my @y = split('_', $b);
        return $order{$x[0]} <=> $order{$y[0]};
}

# Save expenses budgets to csv.
# $data contains the collected budgets, $money_type can be either 'uitgaven' (expenses) or 'inkomsten' (income).
sub save_data {
        my ($data, $money_type, $column_names, $csv_out) = @_;

        # Convert the datia in the hash to arrays which each represent a row which will be written to the csv.
        my %data = %{$data};
        my @data_rows;
        push @data_rows, $column_names;
        # Loop over all departments, sorted by their Roman numeral/character ID.
        for my $department (sort custom_sort keys %data) {
                # Loop over all bureaus, sorted by their numeric ID.
                for my $bureau (sort {(split("_", $a))[0] <=> (split("_", $b))[0]} keys $data{$department}) {
                        my @budgets;
                        for my $year (@years) {
                                my $ar_budget = $data{$department}{$bureau}{$year};
                                my @budget;
                                # Some departments are not listed in every year's budget.
                                # If it doesn't exist then set the budget to 0.
                                if (defined $ar_budget) {
                                        @budget = @{$ar_budget};
                                }
                                else {
                                        push @budget, 0;
                                        #foreach (@budget_types) {
                                        #        push @budget, 0;
                                        #}
                                }
                                push @budgets, @budget;
                        }
                        # Separate the code and name of the department and bureau keys.
                        my @department = split('_', $department);
                        my @bureau = split('_', $bureau);
                        push @data_rows, [$department[0], $department[1], $bureau[0], $bureau[1], @budgets];
                }
        }

        open(my $fh, ">:encoding(utf8)", "nl_rijksbegroting_" . $money_type . ".csv") or die "nl_rijksbegroting_" . $money_type . ".csv: $!\n";
        $csv_out->print ($fh, $_) for @data_rows;
        close $fh;
}

######################
# SCRIPT
######################
open(my $fh, '<', 'scraped_data.json');

my $json_text;
local $/;
$json_text .= <$fh>;
close $fh;
my @data = @{decode_json($json_text)};

my %data_income;
my %data_expenses;

for my $row (@data) {
    my %row = %$row;
    #print "$row{'year'}\n";

    #print "$row{department_code}_$row{department_name}\n";
    #print "$row{bureau_code}_$row{burea_name}\n";
    #print "$row{year}\n";
    #print "$row{ontvangsten}\n";
    $data_income{"$row{department_code}_$row{department_name}"}{"$row{bureau_code}_$row{bureau_name}"}{$row{year}} = [$row{ontvangsten}];
    $data_expenses{"$row{department_code}_$row{department_name}"}{"$row{bureau_code}_$row{bureau_name}"}{$row{year}} = [$row{uitgaven}];
}

my $csv_out = Text::CSV->new({
        sep_char  => ',',
        binary    => 1, # Allow special character. Always set this
        auto_diag => 1 # Report irregularities immediately
});

# Print newline at end of line when creating the output csv.
$csv_out->eol ("\n");

my @column_names = ('Agency Code', 'Agency Name', 'Bureau Code', 'Bureau Name', '2012', '2013', '2014');

# Save the expenses and income data to csv.
&save_data(\%data_expenses, 'uitgaven', \@column_names, $csv_out);
&save_data(\%data_income, 'inkomsten', \@column_names, $csv_out);

print "Finished processing\n";
